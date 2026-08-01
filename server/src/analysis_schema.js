import { MODEL, SCHEMA_VERSION } from "./constants.js";

const nullableString = {
  type: ["string", "null"],
};

const nullableInteger = {
  type: ["integer", "null"],
};

const confidence = {
  type: "number",
  minimum: 0,
  maximum: 1,
};

const evidenceIds = {
  type: "array",
  items: { type: "string" },
};

const strictObject = (properties) => ({
  type: "object",
  properties,
  required: Object.keys(properties),
  additionalProperties: false,
});

export const ANALYSIS_SCHEMA = {
  type: "object",
  properties: {
    schemaVersion: {
      type: "string",
      enum: [SCHEMA_VERSION],
    },
    model: {
      type: "string",
      enum: [MODEL],
    },
    domain: {
      type: "string",
      enum: ["beauty", "food", "unknown"],
    },
    contentKind: {
      type: "string",
      enum: [
        "beauty_product",
        "recipe",
        "sauce_recipe",
        "commerce_product",
        "product_review",
        "menu_comparison",
        "unknown",
      ],
    },
    completeness: {
      type: "string",
      enum: [
        "complete",
        "partial",
        "conflicted",
        "needs_review",
        "unsupported",
      ],
    },
    title: strictObject({
      value: nullableString,
      status: {
        type: "string",
        enum: ["observed", "inferred", "missing"],
      },
      confidence,
      evidenceIds,
    }),
    summary: {
      type: "string",
    },
    evidence: {
      type: "array",
      items: strictObject({
        id: { type: "string" },
        text: { type: "string" },
        region: {
          type: "string",
          enum: [
            "image_text",
            "caption",
            "overlay",
            "product_panel",
            "menu",
            "unknown",
          ],
        },
        confidence,
      }),
    },
    ingredientGroups: {
      type: "array",
      items: strictObject({
        name: { type: "string" },
        ingredients: {
          type: "array",
          items: strictObject({
            name: { type: "string" },
            amount: nullableString,
            unit: nullableString,
            preparation: nullableString,
            optional: { type: "boolean" },
            originalText: { type: "string" },
            confidence,
            evidenceIds,
          }),
        },
      }),
    },
    steps: {
      type: "array",
      items: strictObject({
        order: { type: "integer" },
        instruction: { type: "string" },
        durationSeconds: nullableInteger,
        temperature: nullableString,
        evidenceIds,
      }),
    },
    facts: {
      type: "array",
      items: strictObject({
        label: { type: "string" },
        value: { type: "string" },
        confidence,
        evidenceIds,
      }),
    },
    conflicts: {
      type: "array",
      items: strictObject({
        field: { type: "string" },
        details: { type: "string" },
        evidenceIds,
      }),
    },
    warnings: {
      type: "array",
      items: { type: "string" },
    },
  },
  required: [
    "schemaVersion",
    "model",
    "domain",
    "contentKind",
    "completeness",
    "title",
    "summary",
    "evidence",
    "ingredientGroups",
    "steps",
    "facts",
    "conflicts",
    "warnings",
  ],
  additionalProperties: false,
};

export const ANALYSIS_TEXT_FORMAT = Object.freeze({
  type: "json_schema",
  name: "ori_capture_analysis",
  strict: true,
  schema: ANALYSIS_SCHEMA,
});
