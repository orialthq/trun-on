/// Decides which business the retrieved pages are actually about.
///
/// This is the gate. Everything after it attaches facts to a shop, so getting it
/// wrong is worse than getting nothing: a reader who saved 어니언 성수 and is
/// shown 어니언 미아's hours has been actively misled, while an empty axis is
/// merely unhelpful. So this refuses rather than guesses, and the caller must not
/// judge anything when it refuses.
///
/// Measured on real retrieval output for ten shops it resolved nine and refused
/// one — the refusal being a run where the only listing name that came back was a
/// different restaurant entirely.

import { nameMatches, normalizeName } from "./place_match.js";

/// Groups the candidate names that denote one business.
///
/// A single shop comes back spelled several ways — 하동관, 하동관 본점,
/// 하동관 명동본점 — and treating those as three rival candidates is what made a
/// plain "is there exactly one match?" check give up on a shop it had already
/// found. Names that match each other belong to the same cluster.
function clusterNames(capturedName, names) {
  const kept = names.filter((name) => nameMatches(capturedName, name));
  const clusters = [];
  for (const name of kept) {
    const home = clusters.find((cluster) =>
      cluster.some((member) => nameMatches(member, name) || nameMatches(name, member)),
    );
    if (home) home.push(name);
    else clusters.push([name]);
  }
  return clusters;
}

/// The area the screenshot showed, used only to break a tie.
///
/// It never promotes a name the match check already rejected on its own terms —
/// it only chooses among candidates that were already plausible.
function pickByArea(clusters, area) {
  if (!area) return null;
  const needle = normalizeName(area);
  if (needle.length === 0) return null;
  const hits = clusters.filter((cluster) =>
    cluster.some((name) => normalizeName(name).includes(needle)),
  );
  return hits.length === 1 ? hits[0] : null;
}

/// A chain branch names its area instead of a 지점 suffix — 어니언 성수 beside
/// 어니언 미아 — so the name check rejects both and there is nothing to cluster.
/// The captured area picks the branch when, and only when, it picks exactly one.
function branchByArea(capturedName, area, names) {
  if (!area) return null;
  const head = normalizeName(capturedName);
  const needle = normalizeName(area);
  if (head.length === 0 || needle.length === 0) return null;
  const hits = names.filter((name) => {
    const normalized = normalizeName(name);
    return normalized.startsWith(head) && normalized.includes(needle);
  });
  return hits.length === 1 ? hits : null;
}

/// Resolves the listings a retrieval pass returned to one business.
///
/// Returns `{ resolvedName, aliases, reason }` on success, or
/// `{ resolvedName: null, reason }` when the caller must stop. `reason` is for
/// the debug log; nothing downstream branches on its text.
export function resolvePlaceIdentity({ name, searchArea = null, listings = [] }) {
  const captured = typeof name === "string" ? name.trim() : "";
  if (captured.length === 0) {
    return { resolvedName: null, aliases: [], reason: "화면에서 상호명을 못 읽음" };
  }

  const names = [
    ...new Set(
      listings
        .map((listing) => listing?.nameOnPage)
        .filter((value) => typeof value === "string" && value.trim().length > 0)
        .map((value) => value.trim()),
    ),
  ];
  if (names.length === 0) {
    return { resolvedName: null, aliases: [], reason: "리스팅을 못 찾음" };
  }

  const clusters = clusterNames(captured, names);

  if (clusters.length === 1) {
    return {
      resolvedName: clusters[0][0],
      aliases: clusters[0],
      reason: "후보가 한 가게",
    };
  }

  if (clusters.length === 0) {
    const branch = branchByArea(captured, searchArea, names);
    if (branch) {
      return { resolvedName: branch[0], aliases: branch, reason: "지역으로 지점 확정" };
    }
    return { resolvedName: null, aliases: [], reason: "이름이 맞는 후보 없음" };
  }

  const byArea = pickByArea(clusters, searchArea);
  if (byArea) {
    return { resolvedName: byArea[0], aliases: byArea, reason: "지역으로 지점 확정" };
  }
  return {
    resolvedName: null,
    aliases: [],
    reason: `서로 다른 ${clusters.length}곳`,
  };
}
