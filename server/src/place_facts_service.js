import { buildExtractionRequest, extractionItems } from "./extraction_prompt.js";
import { deriveFacts } from "./facts_derivation.js";
import { normalizeName, selectMapsPlace } from "./place_match.js";

/// The facts lookup, store-first.
///
/// A place already fetched within the TTL costs nothing and answers instantly
/// from its stored evidence. A new place costs two Serper queries and one
/// extraction pass — about $0.004 — and every review extracted is keyed by its
/// id, so the next visit only pays for reviews that did not exist yet.
const FRESH_MS = 7 * 24 * 3600 * 1000;
/// Identity outlives facts: where a shop *is* changes on the timescale of
/// moves and closures, not menus, so a resolved (name, area) → fid mapping is
/// trusted longer than the facts fetched through it.
const RESOLUTION_FRESH_MS = 30 * 24 * 3600 * 1000;
const MIN_REVIEW_LENGTH = 2;

export function createPlaceFactsService({
  serper,
  transport,
  model,
  store,
  timeoutMs = 30_000,
  now = Date.now,
} = {}) {
  if (!serper) throw new Error("A serper transport is required");
  if (!transport || typeof transport.createResponse !== "function") {
    throw new Error("A transport with createResponse is required");
  }
  if (!store) throw new Error("A place store is required");

  return {
    async lookup({ name, searchArea }) {
      const shopName = typeof name === "string" ? name.trim() : "";
      const area = typeof searchArea === "string" ? searchArea.trim() : "";
      if (shopName.length === 0) return { place: null, reason: "name_missing" };

      // A remembered resolution plus fresh facts answers without touching
      // Serper at all — the repeat lookup costs nothing.
      const nameNorm = normalizeName(shopName);
      const areaNorm = normalizeName(area);
      const remembered = store.getResolution(nameNorm, areaNorm);
      if (remembered && now() - remembered.resolvedAt < RESOLUTION_FRESH_MS) {
        const stored = store.getPlace(remembered.fid);
        const extractedSomething = ["review", "web", "video"].some(
          (source) => store.processedIds(remembered.fid, source).size > 0,
        );
        if (stored && now() - stored.fetchedAt < FRESH_MS && extractedSomething) {
          const derived = deriveFacts({
            place: stored,
            evidence: store.evidenceFor(remembered.fid),
            now: now(),
          });
          return { place: stored, ...derived, fromStore: true };
        }
      }

      const query = [shopName, area].filter((value) => value.length > 0).join(" ");
      const candidates = await serper.maps(query);
      // Every candidate is judged, not just the ranked first; a chain needs the
      // captured area to pick the branch, and no pick means no facts.
      const picked = selectMapsPlace({ name: shopName, area, candidates });
      const record = picked.place;
      if (!record?.fid) {
        return {
          place: null,
          reason: candidates.length === 0 ? "not_found" : picked.reason,
        };
      }

      const fid = record.fid;
      store.saveResolution(nameNorm, areaNorm, fid, { now: now() });
      const stored = store.getPlace(fid);
      // Fresh means fetched recently AND some document actually made it through
      // extraction. A lookup whose extraction failed outright must not coast on
      // its structured fields for a week — the retry is the point.
      const processedAnything = ["review", "web", "video"].some(
        (source) => store.processedIds(fid, source).size > 0,
      );
      const fresh = stored && now() - stored.fetchedAt < FRESH_MS && processedAnything;
      if (!fresh) {
        store.savePlace(
          {
            fid,
            name: record.title,
            address: record.address ?? null,
            latitude: record.latitude ?? null,
            longitude: record.longitude ?? null,
            category: record.type ?? null,
            priceLevel: record.priceLevel ?? null,
            openingHours: record.openingHours ?? null,
            bookingLinks: Array.isArray(record.bookingLinks) ? record.bookingLinks : [],
          },
          { now: now() },
        );
        await extractNewEvidence(fid, record.title);
      }

      const place = store.getPlace(fid);
      const derived = deriveFacts({ place, evidence: store.evidenceFor(fid), now: now() });
      return { place, ...derived, fromStore: Boolean(fresh) };
    },
  };

  /// Reviews and platform notices ride one extraction call. A review is a
  /// visitor's experience; a tabling/catchtable snippet is the owner's own
  /// operating rule (원격 줄서기 시간, 예약 오픈 일정) — different weight, same
  /// shape: a sentence with a source id, extracted once and stored.
  async function extractNewEvidence(fid, placeName) {
    const [reviewsSettled, noticesSettled, videosSettled] = await Promise.allSettled([
      serper.reviews(fid),
      // Diningcode rides the same query for free: OR terms share one credit,
      // and its listing pages carry field-style facts (웨이팅 방법, 편의시설)
      // that reviews rarely state outright.
      serper.search(
        `"${placeName}" (site:tabling.co.kr OR site:app.catchtable.co.kr OR site:diningcode.com)`,
      ),
      serper.videos(`"${placeName}"`),
    ]);

    const documents = [];
    if (reviewsSettled.status === "fulfilled") {
      const seen = store.processedIds(fid, "review");
      for (const review of reviewsSettled.value.reviews) {
        const id = typeof review.id === "string" && review.id ? review.id : null;
        const text = (review.snippet ?? "").trim();
        if (!id || seen.has(id) || text.length < MIN_REVIEW_LENGTH) continue;
        documents.push({
          source: "review",
          sourceId: id,
          text,
          saidAt: typeof review.isoDate === "string" ? review.isoDate : null,
        });
      }
    }
    if (noticesSettled.status === "fulfilled") {
      const seen = store.processedIds(fid, "web");
      for (const row of noticesSettled.value) {
        const link = typeof row.link === "string" ? row.link : "";
        // The site: filter should guarantee this, but a snippet from anywhere
        // else must not enter the store wearing a platform label.
        if (!/tabling\.co\.kr|catchtable\.co\.kr|diningcode\.com/.test(link)) continue;
        const text = [row.title, row.snippet].filter(Boolean).join(" — ").trim();
        if (seen.has(link) || text.length < MIN_REVIEW_LENGTH) continue;
        documents.push({ source: "web", sourceId: link, text, saidAt: null });
      }
    }
    if (videosSettled.status === "fulfilled") {
      const seen = store.processedIds(fid, "video");
      for (const row of videosSettled.value.slice(0, 5)) {
        const link = typeof row.link === "string" ? row.link : "";
        const text = [row.title, row.snippet].filter(Boolean).join(" — ").trim();
        if (!link || seen.has(link) || text.length < MIN_REVIEW_LENGTH) continue;
        documents.push({ source: "video", sourceId: link, text, saidAt: null });
      }
    }
    if (documents.length === 0) return;

    let items = [];
    try {
      const response = await withDeadline(
        (signal) =>
          transport.createResponse(
            buildExtractionRequest({ texts: documents.map((doc) => doc.text), model }),
            { signal },
          ),
        timeoutMs,
      );
      items = extractionItems(response, documents.map((doc) => doc.text));
    } catch {
      // Extraction failing must not fail the lookup — structured fields still
      // answer, and the documents stay unprocessed so the next visit retries.
      return;
    }

    store.addEvidence(
      fid,
      items.map((item) => ({
        source: documents[item.index].source,
        sourceId: documents[item.index].sourceId,
        topic: item.topic,
        quote: item.quote,
        saidAt: documents[item.index].saidAt,
      })),
      { now: now() },
    );
    // Marked only after a successful pass: extraction is once per document, and
    // "once" should mean once it actually happened.
    for (const source of ["review", "web", "video"]) {
      const ids = documents.filter((doc) => doc.source === source).map((doc) => doc.sourceId);
      if (ids.length > 0) store.markProcessed(fid, source, ids);
    }
  }
}

async function withDeadline(run, timeoutMs) {
  const controller = new AbortController();
  let timer;
  try {
    const deadline = new Promise((_, reject) => {
      timer = setTimeout(() => {
        controller.abort();
        reject(new Error("timeout"));
      }, timeoutMs);
      timer.unref?.();
    });
    return await Promise.race([run(controller.signal), deadline]);
  } finally {
    clearTimeout(timer);
  }
}
