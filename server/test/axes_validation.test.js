import assert from "node:assert/strict";
import test from "node:test";
import { validateAnalysisResult } from "../src/result_validation.js";
import { makeValidAnalysis } from "./fixtures.js";

function withAxes(axes) {
  const result = makeValidAnalysis();
  result.axes = { ...result.axes, ...axes };
  return result;
}

const kind = (value, observations, confidence = 0.8) => ({
  observations,
  value,
  confidence,
  evidenceIds: ["e1"],
});

const label = (value, confidence = 0.8) => ({
  value,
  confidence,
  evidenceIds: ["e1"],
});

test("accepts several kind labels, each with what it observed", () => {
  const validated = validateAnalysisResult(
    withAxes({
      kind: [
        kind("파스타", ["까르보나라 18,000", "봉골레 17,000"]),
        kind("와인바", ["글라스 와인 9,000"], 0.6),
      ],
    }),
  );

  assert.deepEqual(
    validated.axes.kind.map((entry) => entry.value),
    ["파스타", "와인바"],
  );
  assert.deepEqual(validated.axes.kind[0].quotes, [
    "까르보나라 18,000",
    "봉골레 17,000",
  ]);
});

test("drops a kind label that observed nothing", () => {
  // Without an observation the label is a guess wearing a label's clothes.
  const validated = validateAnalysisResult(
    withAxes({ kind: [kind("파스타", [])] }),
  );

  assert.deepEqual(validated.axes.kind, []);
});

test("the screenshot pass leaves the facts axes to the web", () => {
  // A caption almost never states a price band, a queue, or a parking lot, so
  // the axes are present and empty rather than guessed from a photo.
  const validated = validateAnalysisResult(makeValidAnalysis());

  assert.deepEqual(validated.axes.price, []);
  assert.deepEqual(validated.axes.waiting, []);
  assert.deepEqual(validated.axes.parking, []);
  // The model is not even offered them.
  const offered = Object.keys(makeValidAnalysis().axes);
  assert.deepEqual(offered, ["kind", "location"]);
});

test("savedReason is never filled by the model", () => {
  const validated = validateAnalysisResult(makeValidAnalysis());

  assert.deepEqual(validated.axes.savedReason, []);
  // The model is not even offered the axis.
  assert.equal("savedReason" in makeValidAnalysis().axes, false);
});

test("rejects a repeated label on one axis", () => {
  assert.throws(() =>
    validateAnalysisResult(withAxes({ location: [label("성수"), label("성수")] })),
  );
});

test("rejects a label that would tag only this capture", () => {
  assert.throws(() =>
    validateAnalysisResult(
      withAxes({ kind: [kind("리스토란테 오늘 #맛집", ["메뉴"])] }),
    ),
  );
});

test("rejects a renamed axis", () => {
  const result = makeValidAnalysis();
  result.axes = { kind: [], location: [], mood: [] };

  assert.throws(() => validateAnalysisResult(result));
});

test("rejects runaway label counts", () => {
  const many = Array.from({ length: 9 }, (_, index) => label(`분류${index}`));

  assert.throws(() => validateAnalysisResult(withAxes({ location: many })));
});
