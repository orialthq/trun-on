import { DEFAULT_ANALYSIS_TIMEOUT_MS, MODEL } from "./constants.js";
import { ENRICHMENT_TEXT_FORMAT } from "./enrichment_schema.js";
import { buildEnrichmentRequest } from "./enrichment_prompt.js";
import { OpenAITransportError } from "./errors.js";

const AXES = Object.freeze(["kind", "occasion", "priceRange"]);
const MAX_LABELS_PER_AXIS = 4;
const LABEL_PATTERN =
  /^[가-힣ㄱ-ㅎㅏ-ㅣA-Za-z0-9]+(?:[ ·ㆍ&/+＋-][가-힣ㄱ-ㅎㅏ-ㅣA-Za-z0-9]+)*$/u;

/// Fills the axes a screenshot cannot support — mainly 가격대 — by searching the
/// web for the place the screenshot named.
///
/// This is deliberately a separate pass from the analysis. A failed or empty
/// lookup leaves the capture exactly as the screenshot described it, and web
/// labels stay tagged with their source so the client never presents them as
/// something the user's own screenshot showed.
export function createEnrichmentService({
  transport,
  timeoutMs = DEFAULT_ANALYSIS_TIMEOUT_MS,
} = {}) {
  if (!transport || typeof transport.createResponse !== "function") {
    throw new Error("A transport with createResponse is required");
  }

  return {
    async enrich({ name, searchArea }) {
      const shopName = typeof name === "string" ? name.trim() : "";
      const area = typeof searchArea === "string" ? searchArea.trim() : "";
      // An area on its own would return whichever shop the web likes best, so
      // the name is what makes this lookup meaningful at all.
      if (shopName.length === 0) {
        return emptyEnrichment();
      }
      const query = [shopName, area].filter((value) => value.length > 0).join(" ");

      const controller = new AbortController();
      let timeout;
      try {
        const deadline = new Promise((_, reject) => {
          timeout = setTimeout(() => {
            controller.abort();
            reject(new OpenAITransportError("timeout", { retryable: true }));
          }, timeoutMs);
          timeout.unref?.();
        });
        const response = await Promise.race([
          transport.createResponse(
            buildEnrichmentRequest({
              query,
              model: MODEL,
              textFormat: ENRICHMENT_TEXT_FORMAT,
            }),
            { signal: controller.signal },
          ),
          deadline,
        ]);
        return sanitizeEnrichment(extractJson(response));
      } finally {
        clearTimeout(timeout);
      }
    },
  };
}

function emptyEnrichment() {
  return { matchedName: null, kind: [], occasion: [], priceRange: [] };
}

function extractJson(response) {
  if (!response || typeof response !== "object" || response.error) {
    throw new OpenAITransportError("invalid_response", { retryable: true });
  }
  if (response.status === "incomplete") {
    throw new OpenAITransportError("invalid_response", { retryable: true });
  }

  const text =
    typeof response.output_text === "string" && response.output_text
      ? response.output_text
      : firstOutputText(response);
  try {
    return JSON.parse(text);
  } catch (error) {
    throw new OpenAITransportError("invalid_response", {
      cause: error,
      retryable: true,
    });
  }
}

function firstOutputText(response) {
  const output = Array.isArray(response.output) ? response.output : [];
  for (const item of output) {
    // Web search adds its own output items ahead of the message.
    if (item?.type !== "message") continue;
    for (const content of item.content ?? []) {
      if (typeof content?.text === "string" && content.text) {
        return content.text;
      }
    }
  }
  throw new OpenAITransportError("invalid_response", { retryable: true });
}

/// Drops anything the model returned that the contract does not allow.
///
/// A malformed label is discarded rather than failing the whole lookup: the
/// enrichment is an optional extra, and losing one label is better than losing
/// the capture's other findings.
function sanitizeEnrichment(raw) {
  if (!raw || typeof raw !== "object") {
    return emptyEnrichment();
  }

  const result = emptyEnrichment();
  result.matchedName =
    typeof raw.matchedName === "string" && raw.matchedName.trim().length > 0
      ? raw.matchedName.trim().slice(0, 120)
      : null;

  for (const axis of AXES) {
    const labels = Array.isArray(raw[axis]) ? raw[axis] : [];
    const seen = new Set();
    for (const label of labels) {
      if (result[axis].length >= MAX_LABELS_PER_AXIS) break;
      const value =
        typeof label?.value === "string"
          ? label.value.normalize("NFKC").trim().replace(/\s+/gu, " ")
          : "";
      const length = Array.from(value).length;
      if (length < 2 || length > 20 || !LABEL_PATTERN.test(value)) continue;
      if (seen.has(value)) continue;

      const citation = httpsUrl(label?.citation);
      if (!citation) continue;

      const confidence =
        typeof label?.confidence === "number" &&
        label.confidence >= 0 &&
        label.confidence <= 1
          ? label.confidence
          : 0;

      seen.add(value);
      result[axis].push({ value, confidence, citation });
    }
  }
  return result;
}

function httpsUrl(value) {
  if (typeof value !== "string" || value.length === 0) return null;
  try {
    const url = new URL(value);
    return url.protocol === "https:" ? url.toString() : null;
  } catch {
    return null;
  }
}
