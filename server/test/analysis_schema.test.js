import assert from "node:assert/strict";
import test from "node:test";
import { ANALYSIS_SCHEMA } from "../src/analysis_schema.js";

test("every Structured Outputs object is strict and requires every field", () => {
  const visit = (schema, path) => {
    if (!schema || typeof schema !== "object") {
      return;
    }

    const types = Array.isArray(schema.type) ? schema.type : [schema.type];
    if (types.includes("object")) {
      assert.equal(
        schema.additionalProperties,
        false,
        `${path} must reject additional properties`,
      );
      const propertyNames = Object.keys(schema.properties ?? {}).sort();
      assert.deepEqual(
        [...(schema.required ?? [])].sort(),
        propertyNames,
        `${path} must require every property`,
      );
      for (const [name, property] of Object.entries(schema.properties ?? {})) {
        visit(property, `${path}.properties.${name}`);
      }
    }

    if (schema.items) {
      visit(schema.items, `${path}.items`);
    }
    for (const [index, option] of (schema.anyOf ?? []).entries()) {
      visit(option, `${path}.anyOf[${index}]`);
    }
  };

  visit(ANALYSIS_SCHEMA, "root");
});

test("subcategory contract is bounded and required in schema 1.2", () => {
  assert.deepEqual(ANALYSIS_SCHEMA.properties.schemaVersion.enum, ["1.2"]);
  assert.equal(ANALYSIS_SCHEMA.properties.subcategory.minLength, 2);
  assert.equal(ANALYSIS_SCHEMA.properties.subcategory.maxLength, 20);
  assert.equal(
    new RegExp(ANALYSIS_SCHEMA.properties.subcategory.pattern, "u").test(
      "카페·디저트",
    ),
    true,
  );
  assert.equal(
    new RegExp(ANALYSIS_SCHEMA.properties.subcategory.pattern, "u").test(
      "스킨케어✨",
    ),
    false,
  );
  assert.ok(ANALYSIS_SCHEMA.required.includes("subcategory"));
  assert.ok(ANALYSIS_SCHEMA.required.includes("subcategoryConfidence"));
});
