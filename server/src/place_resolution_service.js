import { selectResolvedPlace } from "./place_match.js";

/// Resolves a captured place to one verified point of interest, or to nothing.
///
/// Retrieval and acceptance are deliberately separate steps. The query sent to
/// the search API is just a net; whether a returned row is *the* place is
/// decided by `selectResolvedPlace`, which checks the captured name and the
/// captured address on their own axes. A row that only matches the net is
/// discarded.
export function createPlaceResolutionService({ transport } = {}) {
  if (!transport || typeof transport.searchKeyword !== "function") {
    throw new Error("A place search transport is required");
  }

  return {
    async resolve({ name, address }, { signal } = {}) {
      const queries = buildQueries({ name, address });
      const seen = new Set();
      const candidates = [];

      for (const query of queries) {
        const documents = await transport.searchKeyword(query, { signal });
        for (const document of documents) {
          if (seen.has(document.id)) continue;
          seen.add(document.id);
          candidates.push(document);
        }
        // Stop as soon as the collected pool yields a single verified match.
        const resolved = selectResolvedPlace({ name, address, candidates });
        if (resolved) {
          return { place: resolved, candidateCount: candidates.length };
        }
      }

      return { place: null, candidateCount: candidates.length };
    },
  };
}

/// Query variants, narrowest first.
///
/// `상호명 + 지역` finds a specific branch; the name alone catches a place whose
/// captured address was an unrelated area tag. Both feed the same acceptance
/// check, so a wider net cannot loosen the result.
function buildQueries({ name, address }) {
  const trimmedName = typeof name === "string" ? name.trim() : "";
  const trimmedAddress = typeof address === "string" ? address.trim() : "";

  const queries = [];
  if (trimmedName && trimmedAddress) {
    queries.push(`${trimmedName} ${trimmedAddress}`);
  }
  if (trimmedName) {
    queries.push(trimmedName);
  }
  if (!trimmedName && trimmedAddress) {
    queries.push(trimmedAddress);
  }
  return [...new Set(queries)];
}
