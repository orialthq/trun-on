import { AppError } from "./errors.js";

/// Serper is where place facts come from now: /maps for the structured record
/// (identity, price level, hours, booking links) and /reviews for the sentences
/// people actually wrote. Measured against the Luna web_search path this is 12x
/// cheaper per shop, and — unlike a model told to search — the same query
/// returns the same rows, which is what lets the store accumulate instead of
/// flapping.
const BASE_URL = "https://google.serper.dev";
const DEFAULT_TIMEOUT_MS = 15_000;

export function createSerperTransport({
  apiKey,
  fetchImpl = fetch,
  timeoutMs = DEFAULT_TIMEOUT_MS,
} = {}) {
  if (typeof apiKey !== "string" || apiKey.length === 0) {
    throw new Error("SERPER_API_KEY is required");
  }

  async function post(path, body, { signal } = {}) {
    const controller = new AbortController();
    const onAbort = () => controller.abort();
    signal?.addEventListener("abort", onAbort, { once: true });
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    timer.unref?.();
    let response;
    try {
      response = await fetchImpl(`${BASE_URL}/${path}`, {
        method: "POST",
        headers: { "X-API-KEY": apiKey, "content-type": "application/json" },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
    } catch (error) {
      throw new AppError("PLACE_FACTS_UPSTREAM", "장소 정보를 불러오지 못했어요.", {
        httpStatus: 502,
        cause: error,
      });
    } finally {
      clearTimeout(timer);
      signal?.removeEventListener("abort", onAbort);
    }
    if (response.status === 429) {
      throw new AppError("PLACE_FACTS_RATE_LIMITED", "장소 조회가 잠시 몰렸어요.", {
        httpStatus: 429,
      });
    }
    if (!response.ok) {
      // The body may carry our API key's remaining quota details; the status is
      // all the caller needs and all the log should see.
      throw new AppError("PLACE_FACTS_UPSTREAM", "장소 정보를 불러오지 못했어요.", {
        httpStatus: 502,
      });
    }
    return response.json();
  }

  return {
    /// The first row is the place record; billing counts the query, not rows.
    async maps(query, { signal } = {}) {
      const result = await post("maps", { q: query, gl: "kr", hl: "ko" }, { signal });
      return Array.isArray(result?.places) ? result.places : [];
    },

    /// Web search, used for platform notices: a shop's own tabling/catchtable
    /// page carries owner-written operating rules (원격 줄서기 시간, 예약 오픈
    /// 일정), and Google's snippet of that page is how we read them — the pages
    /// themselves are SPAs behind a 403 robots.txt, and we do not crawl.
    async search(query, { signal } = {}) {
      const result = await post("search", { q: query, gl: "kr", hl: "ko", num: 10 }, { signal });
      return Array.isArray(result?.organic) ? result.organic : [];
    },

    /// One page is twenty reviews, newest-biased by Google's own relevance.
    /// The caller decides whether a second page is worth another credit.
    async reviews(fid, { nextPageToken, signal } = {}) {
      const body = { fid, gl: "kr", hl: "ko" };
      if (nextPageToken) body.nextPageToken = nextPageToken;
      const result = await post("reviews", body, { signal });
      return {
        reviews: Array.isArray(result?.reviews) ? result.reviews : [],
        nextPageToken: typeof result?.nextPageToken === "string" ? result.nextPageToken : null,
      };
    },
  };
}
