import assert from "node:assert/strict";
import test from "node:test";
import { AppError } from "../src/errors.js";
import { validateAnalyzeRequest } from "../src/request_validation.js";
import { makeValidRequest } from "./fixtures.js";

test("normalizes optional capture metadata to null", () => {
  const result = validateAnalyzeRequest({
    ...makeValidRequest(),
    capture: { id: " capture-1 " },
  });

  assert.deepEqual(result.capture, {
    id: "capture-1",
    sourceApp: null,
    sourceUrl: null,
    capturedAt: null,
    locale: null,
  });
});

test("rejects unexpected request keys", () => {
  assert.throws(
    () =>
      validateAnalyzeRequest({
        ...makeValidRequest(),
        apiKey: "must-never-be-accepted",
      }),
    (error) =>
      error instanceof AppError && error.code === "INVALID_REQUEST",
  );
});

test("rejects a data URL instead of pure base64", () => {
  assert.throws(
    () =>
      validateAnalyzeRequest(
        makeValidRequest({
          image: {
            base64: "data:image/jpeg;base64,/9j/2Q==",
          },
        }),
      ),
    (error) => error instanceof AppError && error.code === "INVALID_IMAGE",
  );
});
