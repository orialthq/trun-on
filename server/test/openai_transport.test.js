import assert from "node:assert/strict";
import test from "node:test";
import { OpenAITransportError } from "../src/errors.js";
import { createOpenAITransport } from "../src/openai_transport.js";

test("posts to Responses API using the injected fetch implementation", async () => {
  let receivedUrl;
  let receivedOptions;
  const transport = createOpenAITransport({
    apiKey: "test-only-key",
    baseUrl: "https://example.invalid/v1",
    fetchImpl: async (url, options) => {
      receivedUrl = url;
      receivedOptions = options;
      return new Response(
        JSON.stringify({ status: "completed", output_text: "{}" }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        },
      );
    },
  });

  const request = { model: "gpt-5.6-luna", store: false };
  const result = await transport.createResponse(request);

  assert.equal(receivedUrl, "https://example.invalid/v1/responses");
  assert.equal(receivedOptions.method, "POST");
  assert.equal(
    receivedOptions.headers.Authorization,
    "Bearer test-only-key",
  );
  assert.deepEqual(JSON.parse(receivedOptions.body), request);
  assert.equal(result.status, "completed");
});

test("maps an injected 429 response without exposing its body", async () => {
  const transport = createOpenAITransport({
    apiKey: "test-only-key",
    fetchImpl: async () =>
      new Response(
        JSON.stringify({
          error: {
            message: "sensitive upstream detail",
          },
        }),
        { status: 429 },
      ),
  });

  await assert.rejects(
    transport.createResponse({}),
    (error) =>
      error instanceof OpenAITransportError &&
      error.kind === "rate_limited" &&
      !error.message.includes("sensitive"),
  );
});

test("bounds an injected slow fetch even when it ignores abort", async () => {
  const transport = createOpenAITransport({
    apiKey: "test-only-key",
    timeoutMs: 10,
    fetchImpl: () =>
      new Promise(() => {
        // The transport deadline must not depend on fetch cooperation.
      }),
  });

  await assert.rejects(
    transport.createResponse({}),
    (error) =>
      error instanceof OpenAITransportError && error.kind === "timeout",
  );
});
