import assert from "node:assert/strict";
import test from "node:test";
import { validateAnalysisResult } from "../src/result_validation.js";
import { makeValidAnalysis } from "./fixtures.js";

function withAxes(axes) {
  const result = makeValidAnalysis();
  result.axes = { ...result.axes, ...axes };
  return result;
}

const label = (value, confidence = 0.8) => ({
  value,
  confidence,
  evidenceIds: ["e1"],
});

test("accepts several labels on one axis", () => {
  const validated = validateAnalysisResult(
    withAxes({ kind: [label("파스타"), label("와인바", 0.6)] }),
  );

  assert.deepEqual(
    validated.axes.kind.map((entry) => entry.value),
    ["파스타", "와인바"],
  );
});

test("accepts every axis empty", () => {
  const validated = validateAnalysisResult(makeValidAnalysis());

  for (const axis of ["kind", "location", "occasion", "priceRange", "savedReason"]) {
    assert.deepEqual(validated.axes[axis], []);
  }
});

test("trims a label the way subcategory is trimmed", () => {
  const validated = validateAnalysisResult(
    withAxes({ location: [label("  성수  ")] }),
  );

  assert.equal(validated.axes.location[0].value, "성수");
});

test("rejects a repeated label on one axis", () => {
  assert.throws(() =>
    validateAnalysisResult(withAxes({ kind: [label("파스타"), label("파스타")] })),
  );
});

test("rejects a label that would tag only this capture", () => {
  assert.throws(() =>
    validateAnalysisResult(withAxes({ kind: [label("리스토란테 오늘 #맛집")] })),
  );
});

test("rejects a renamed axis", () => {
  const result = makeValidAnalysis();
  result.axes = {
    kind: [],
    location: [],
    occasion: [],
    priceRange: [],
    mood: [],
  };

  assert.throws(() => validateAnalysisResult(result));
});

test("rejects runaway label counts", () => {
  const many = Array.from({ length: 9 }, (_, index) => label(`분류${index}`));

  assert.throws(() => validateAnalysisResult(withAxes({ kind: many })));
});

test("rejects a label object with extra fields", () => {
  assert.throws(() =>
    validateAnalysisResult(
      withAxes({ kind: [{ ...label("파스타"), source: "web" }] }),
    ),
  );
});
