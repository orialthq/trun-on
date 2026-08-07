import { DEFAULT_UPSTREAM_TIMEOUT_MS } from "./constants.js";
import { PlaceSearchTransportError } from "./errors.js";

const MAX_RESPONSE_BYTES = 256 * 1024;
const MAX_DOCUMENTS = 15;

/// Kakao Local keyword search.
///
/// Only the fields Trun On matches on or pins with are kept; phone numbers and
/// other personal-adjacent metadata are dropped at the boundary so they never
/// reach a log, the client, or storage.
export function createKakaoTransport({
  apiKey,
  fetchImpl = globalThis.fetch,
  baseUrl = "https://dapi.kakao.com/v2/local/search",
  timeoutMs = DEFAULT_UPSTREAM_TIMEOUT_MS,
} = {}) {
  if (typeof apiKey !== "string" || apiKey.length === 0) {
    throw new Error("KAKAO_REST_API_KEY is required");
  }
  if (typeof fetchImpl !== "function") {
    throw new Error("A fetch implementation is required");
  }

  return {
    async searchKeyword(query, { signal } = {}) {
      if (typeof query !== "string" || query.trim().length === 0) {
        return [];
      }

      const controller = new AbortController();
      const abort = () => controller.abort();
      signal?.addEventListener("abort", abort, { once: true });
      const timeout = setTimeout(abort, timeoutMs);
      timeout.unref?.();

      let response;
      try {
        const url = new URL(`${baseUrl}/keyword.json`);
        url.searchParams.set("query", query.trim());
        url.searchParams.set("size", String(MAX_DOCUMENTS));
        response = await fetchImpl(url.toString(), {
          method: "GET",
          headers: { Authorization: `KakaoAK ${apiKey}` },
          signal: controller.signal,
        });
      } catch (error) {
        if (controller.signal.aborted) {
          throw new PlaceSearchTransportError("timeout", { retryable: true });
        }
        throw new PlaceSearchTransportError("unavailable", {
          cause: error,
          retryable: true,
        });
      } finally {
        clearTimeout(timeout);
        signal?.removeEventListener("abort", abort);
      }

      if (!response.ok) {
        throw mapUpstreamStatus(response.status);
      }

      const text = await readBoundedText(response);
      let payload;
      try {
        payload = JSON.parse(text);
      } catch (error) {
        throw new PlaceSearchTransportError("invalid_response", {
          cause: error,
          retryable: true,
        });
      }

      const documents = Array.isArray(payload?.documents) ? payload.documents : [];
      return documents.slice(0, MAX_DOCUMENTS).map(toCandidate).filter(Boolean);
    },
  };
}

function toCandidate(document) {
  const id = typeof document?.id === "string" ? document.id : null;
  const name = typeof document?.place_name === "string" ? document.place_name : null;
  const longitude = Number.parseFloat(document?.x);
  const latitude = Number.parseFloat(document?.y);
  if (!id || !name || !Number.isFinite(longitude) || !Number.isFinite(latitude)) {
    return null;
  }
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return null;
  }
  return {
    id,
    name,
    address: stringOrNull(document?.address_name),
    roadAddress: stringOrNull(document?.road_address_name),
    category: stringOrNull(document?.category_group_name),
    latitude,
    longitude,
    placeUrl: httpsUrlOrNull(document?.place_url),
  };
}

function stringOrNull(value) {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

function httpsUrlOrNull(value) {
  const candidate = stringOrNull(value);
  if (!candidate) return null;
  try {
    return new URL(candidate).protocol === "https:" ? candidate : null;
  } catch {
    return null;
  }
}

async function readBoundedText(response) {
  const body = response.body;
  if (!body || typeof body.getReader !== "function") {
    const text = await response.text();
    if (text.length > MAX_RESPONSE_BYTES) {
      throw new PlaceSearchTransportError("invalid_response", { retryable: false });
    }
    return text;
  }

  const reader = body.getReader();
  const decoder = new TextDecoder();
  let total = 0;
  let text = "";
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_RESPONSE_BYTES) {
      await reader.cancel();
      throw new PlaceSearchTransportError("invalid_response", { retryable: false });
    }
    text += decoder.decode(value, { stream: true });
  }
  return text + decoder.decode();
}

function mapUpstreamStatus(status) {
  if (status === 401 || status === 403) {
    return new PlaceSearchTransportError("authentication", {
      upstreamStatus: status,
    });
  }
  if (status === 429) {
    return new PlaceSearchTransportError("rate_limited", {
      upstreamStatus: status,
      retryable: true,
    });
  }
  return new PlaceSearchTransportError("unavailable", {
    upstreamStatus: status,
    retryable: status >= 500,
  });
}
