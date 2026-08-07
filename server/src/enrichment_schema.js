const LABEL_PATTERN =
  "^[가-힣ㄱ-ㅎㅏ-ㅣA-Za-z0-9]+(?:[ ·ㆍ&/+＋-][가-힣ㄱ-ㅎㅏ-ㅣA-Za-z0-9]+)*$";

/// A label found on the web rather than on the screen.
///
/// `citation` is required, not optional. A label nobody can trace back to a page
/// is indistinguishable from a guess, and the whole point of this pass is that
/// the reader can check it.
const webLabel = {
  type: "object",
  properties: {
    value: {
      type: "string",
      minLength: 2,
      maxLength: 20,
      pattern: LABEL_PATTERN,
    },
    confidence: { type: "number", minimum: 0, maximum: 1 },
    citation: { type: "string", minLength: 8, maxLength: 400 },
  },
  required: ["value", "confidence", "citation"],
  additionalProperties: false,
};

const axis = { type: "array", maxItems: 4, items: webLabel };

export const ENRICHMENT_SCHEMA = {
  type: "object",
  properties: {
    // The place the search actually landed on, so the client can tell whether
    // the results describe the shop it asked about.
    matchedName: { type: ["string", "null"], maxLength: 120 },
    kind: axis,
    occasion: axis,
    priceRange: axis,
  },
  required: ["matchedName", "kind", "occasion", "priceRange"],
  additionalProperties: false,
};

export const ENRICHMENT_TEXT_FORMAT = {
  type: "json_schema",
  name: "trun_on_place_enrichment",
  strict: true,
  schema: ENRICHMENT_SCHEMA,
};
