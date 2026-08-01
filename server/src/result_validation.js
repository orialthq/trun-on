import { MODEL, SCHEMA_VERSION } from "./constants.js";
import { OpenAITransportError } from "./errors.js";

const DOMAINS = new Set(["beauty", "food", "unknown"]);
const CONTENT_KINDS = new Set([
  "beauty_product",
  "recipe",
  "sauce_recipe",
  "commerce_product",
  "product_review",
  "menu_comparison",
  "place",
  "unknown",
]);
const COMPLETENESS = new Set([
  "complete",
  "partial",
  "conflicted",
  "needs_review",
  "unsupported",
]);
const TITLE_STATUSES = new Set(["observed", "inferred", "missing"]);
const REGIONS = new Set([
  "image_text",
  "caption",
  "overlay",
  "product_panel",
  "menu",
  "unknown",
]);
const ROOT_KEYS = new Set([
  "schemaVersion",
  "model",
  "domain",
  "contentKind",
  "completeness",
  "title",
  "place",
  "summary",
  "evidence",
  "ingredientGroups",
  "steps",
  "facts",
  "conflicts",
  "warnings",
]);

function invalid(message) {
  return new OpenAITransportError("invalid_response", {
    cause: new Error(message),
    retryable: true,
  });
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function assertExactKeys(object, keys, path) {
  if (!isObject(object)) {
    throw invalid(`${path} is not an object`);
  }
  const actual = Object.keys(object);
  if (
    actual.length !== keys.size ||
    actual.some((key) => !keys.has(key))
  ) {
    throw invalid(`${path} has unexpected keys`);
  }
}

function assertString(value, path, { nullable = false, nonEmpty = true } = {}) {
  if (nullable && value === null) {
    return;
  }
  if (
    typeof value !== "string" ||
    (nonEmpty && value.trim().length === 0)
  ) {
    throw invalid(`${path} is not a valid string`);
  }
}

function assertConfidence(value, path) {
  if (typeof value !== "number" || value < 0 || value > 1) {
    throw invalid(`${path} is not a confidence`);
  }
}

function assertStringArray(value, path, { nonEmptyItems = true } = {}) {
  if (!Array.isArray(value)) {
    throw invalid(`${path} is not an array`);
  }
  value.forEach((item, index) =>
    assertString(item, `${path}[${index}]`, { nonEmpty: nonEmptyItems }),
  );
}

export function validateAnalysisResult(result) {
  assertExactKeys(result, ROOT_KEYS, "result");

  if (result.schemaVersion !== SCHEMA_VERSION || result.model !== MODEL) {
    throw invalid("schema version or model mismatch");
  }
  if (!DOMAINS.has(result.domain)) {
    throw invalid("invalid domain");
  }
  if (!CONTENT_KINDS.has(result.contentKind)) {
    throw invalid("invalid content kind");
  }
  if (!COMPLETENESS.has(result.completeness)) {
    throw invalid("invalid completeness");
  }
  assertString(result.summary, "summary", { nonEmpty: false });

  assertExactKeys(
    result.title,
    new Set(["value", "status", "confidence", "evidenceIds"]),
    "title",
  );
  assertString(result.title.value, "title.value", { nullable: true });
  if (!TITLE_STATUSES.has(result.title.status)) {
    throw invalid("invalid title status");
  }
  if (
    (result.title.status === "missing" && result.title.value !== null) ||
    (result.title.status !== "missing" && result.title.value === null)
  ) {
    throw invalid("title status and value mismatch");
  }
  assertConfidence(result.title.confidence, "title.confidence");
  assertStringArray(result.title.evidenceIds, "title.evidenceIds");

  assertExactKeys(
    result.place,
    new Set(["name", "address", "category", "confidence", "evidenceIds"]),
    "place",
  );
  assertString(result.place.name, "place.name", { nullable: true });
  assertString(result.place.address, "place.address", { nullable: true });
  const placeCategories = new Set([
    "restaurant",
    "cafe",
    "beauty",
    "shopping",
    "lodging",
    "activity",
    "other",
  ]);
  if (
    result.place.category !== null &&
    !placeCategories.has(result.place.category)
  ) {
    throw invalid("place.category is invalid");
  }
  assertConfidence(result.place.confidence, "place.confidence");
  assertStringArray(result.place.evidenceIds, "place.evidenceIds");
  const hasPlace = result.place.name !== null || result.place.address !== null;
  if (
    (!hasPlace &&
      (result.place.category !== null ||
        result.place.confidence !== 0 ||
        result.place.evidenceIds.length > 0)) ||
    (hasPlace && result.place.category === null)
  ) {
    throw invalid("place fields are inconsistent");
  }

  if (!Array.isArray(result.evidence)) {
    throw invalid("evidence is not an array");
  }
  const evidenceIdSet = new Set();
  result.evidence.forEach((item, index) => {
    const path = `evidence[${index}]`;
    assertExactKeys(
      item,
      new Set(["id", "text", "region", "confidence"]),
      path,
    );
    assertString(item.id, `${path}.id`);
    assertString(item.text, `${path}.text`);
    if (!REGIONS.has(item.region)) {
      throw invalid(`${path}.region is invalid`);
    }
    assertConfidence(item.confidence, `${path}.confidence`);
    if (evidenceIdSet.has(item.id)) {
      throw invalid(`duplicate evidence id: ${item.id}`);
    }
    evidenceIdSet.add(item.id);
  });

  const referenceLists = [
    ["title.evidenceIds", result.title.evidenceIds],
    ["place.evidenceIds", result.place.evidenceIds],
  ];

  if (!Array.isArray(result.ingredientGroups)) {
    throw invalid("ingredientGroups is not an array");
  }
  result.ingredientGroups.forEach((group, groupIndex) => {
    const groupPath = `ingredientGroups[${groupIndex}]`;
    assertExactKeys(group, new Set(["name", "ingredients"]), groupPath);
    assertString(group.name, `${groupPath}.name`);
    if (!Array.isArray(group.ingredients)) {
      throw invalid(`${groupPath}.ingredients is not an array`);
    }
    group.ingredients.forEach((ingredient, ingredientIndex) => {
      const path = `${groupPath}.ingredients[${ingredientIndex}]`;
      assertExactKeys(
        ingredient,
        new Set([
          "name",
          "amount",
          "unit",
          "preparation",
          "optional",
          "originalText",
          "confidence",
          "evidenceIds",
        ]),
        path,
      );
      assertString(ingredient.name, `${path}.name`);
      assertString(ingredient.amount, `${path}.amount`, { nullable: true });
      assertString(ingredient.unit, `${path}.unit`, { nullable: true });
      assertString(ingredient.preparation, `${path}.preparation`, {
        nullable: true,
      });
      if (typeof ingredient.optional !== "boolean") {
        throw invalid(`${path}.optional is not a boolean`);
      }
      assertString(ingredient.originalText, `${path}.originalText`);
      assertConfidence(ingredient.confidence, `${path}.confidence`);
      assertStringArray(ingredient.evidenceIds, `${path}.evidenceIds`);
      referenceLists.push([`${path}.evidenceIds`, ingredient.evidenceIds]);
    });
  });

  if (!Array.isArray(result.steps)) {
    throw invalid("steps is not an array");
  }
  result.steps.forEach((step, index) => {
    const path = `steps[${index}]`;
    assertExactKeys(
      step,
      new Set([
        "order",
        "instruction",
        "durationSeconds",
        "temperature",
        "evidenceIds",
      ]),
      path,
    );
    if (!Number.isInteger(step.order) || step.order < 1) {
      throw invalid(`${path}.order is invalid`);
    }
    assertString(step.instruction, `${path}.instruction`);
    if (
      step.durationSeconds !== null &&
      (!Number.isInteger(step.durationSeconds) || step.durationSeconds < 0)
    ) {
      throw invalid(`${path}.durationSeconds is invalid`);
    }
    assertString(step.temperature, `${path}.temperature`, { nullable: true });
    assertStringArray(step.evidenceIds, `${path}.evidenceIds`);
    referenceLists.push([`${path}.evidenceIds`, step.evidenceIds]);
  });

  for (const [key, keys] of [
    ["facts", new Set(["label", "value", "confidence", "evidenceIds"])],
    ["conflicts", new Set(["field", "details", "evidenceIds"])],
  ]) {
    if (!Array.isArray(result[key])) {
      throw invalid(`${key} is not an array`);
    }
    result[key].forEach((item, index) => {
      const path = `${key}[${index}]`;
      assertExactKeys(item, keys, path);
      if (key === "facts") {
        assertString(item.label, `${path}.label`);
        assertString(item.value, `${path}.value`);
        assertConfidence(item.confidence, `${path}.confidence`);
      } else {
        assertString(item.field, `${path}.field`);
        assertString(item.details, `${path}.details`);
      }
      assertStringArray(item.evidenceIds, `${path}.evidenceIds`);
      referenceLists.push([`${path}.evidenceIds`, item.evidenceIds]);
    });
  }

  assertStringArray(result.warnings, "warnings");

  for (const [path, ids] of referenceLists) {
    for (const id of ids) {
      if (!evidenceIdSet.has(id)) {
        throw invalid(`${path} references unknown evidence id: ${id}`);
      }
    }
  }

  return result;
}
