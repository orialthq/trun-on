import assert from "node:assert/strict";
import test from "node:test";
import { createEnrichmentService } from "../src/enrichment_service.js";

function transportReturning(payload) {
  const requests = [];
  return {
    requests,
    transport: {
      async createResponse(body) {
        requests.push(body);
        return { status: "completed", output_text: JSON.stringify(payload) };
      },
    },
  };
}

const cited = (value, citation = "https://example.com/a") => ({
  value,
  confidence: 0.8,
  citation,
});

test("searches the shop name with its area and enables web search", async () => {
  const { requests, transport } = transportReturning({
    matchedName: "페스카데리아",
    kind: [cited("파스타")],
    occasion: [],
    priceRange: [cited("3만원대 이상")],
  });

  const result = await createEnrichmentService({ transport }).enrich({
    name: "페스카데리아",
    searchArea: "성수",
  });

  const request = requests[0];
  assert.equal(request.tools[0].type, "web_search");
  assert.equal(request.store, false);
  assert.match(JSON.stringify(request.input), /페스카데리아 성수/);
  assert.equal(result.priceRange[0].value, "3만원대 이상");
  assert.equal(result.matchedName, "페스카데리아");
});

test("drops a label with no citation", async () => {
  const { transport } = transportReturning({
    matchedName: null,
    kind: [{ value: "파스타", confidence: 0.9 }],
    occasion: [],
    priceRange: [],
  });

  const result = await createEnrichmentService({ transport }).enrich({
    name: "가게",
    searchArea: "성수",
  });

  // A label nobody can check is indistinguishable from a guess.
  assert.deepEqual(result.kind, []);
});

test("drops a citation that is not https", async () => {
  const { transport } = transportReturning({
    matchedName: null,
    kind: [cited("파스타", "http://example.com/a")],
    occasion: [],
    priceRange: [],
  });

  const result = await createEnrichmentService({ transport }).enrich({
    name: "가게",
  });

  assert.deepEqual(result.kind, []);
});

test("drops a label that is not a reusable phrase", async () => {
  const { transport } = transportReturning({
    matchedName: null,
    kind: [cited("페스카데리아 #성수맛집 🍝")],
    occasion: [cited("데이트")],
    priceRange: [],
  });

  const result = await createEnrichmentService({ transport }).enrich({
    name: "가게",
  });

  assert.deepEqual(result.kind, []);
  assert.equal(result.occasion[0].value, "데이트");
});

test("keeps one of a repeated label and bounds the count", async () => {
  const { transport } = transportReturning({
    matchedName: null,
    kind: [cited("파스타"), cited("파스타"), cited("와인바")],
    occasion: Array.from({ length: 9 }, (_, index) => cited(`상황${index}`)),
    priceRange: [],
  });

  const result = await createEnrichmentService({ transport }).enrich({
    name: "가게",
  });

  assert.deepEqual(
    result.kind.map((label) => label.value),
    ["파스타", "와인바"],
  );
  assert.equal(result.occasion.length, 4);
});

test("an unidentified place is an empty answer, not an error", async () => {
  const { transport } = transportReturning({
    matchedName: null,
    kind: [],
    occasion: [],
    priceRange: [],
  });

  const result = await createEnrichmentService({ transport }).enrich({
    name: "존재하지않는가게",
    searchArea: "성수",
  });

  assert.deepEqual(result, {
    matchedName: null,
    kind: [],
    occasion: [],
    priceRange: [],
  });
});

test("skips the call entirely without a name", async () => {
  const { requests, transport } = transportReturning({});

  const result = await createEnrichmentService({ transport }).enrich({
    name: "   ",
    searchArea: "성수",
  });

  assert.equal(requests.length, 0);
  assert.deepEqual(result.kind, []);
});

test("reads the message item when output_text is absent", async () => {
  const transport = {
    async createResponse() {
      return {
        status: "completed",
        output: [
          { type: "web_search_call", status: "completed" },
          {
            type: "message",
            content: [
              {
                type: "output_text",
                text: JSON.stringify({
                  matchedName: "가게",
                  kind: [cited("파스타")],
                  occasion: [],
                  priceRange: [],
                }),
              },
            ],
          },
        ],
      };
    },
  };

  const result = await createEnrichmentService({ transport }).enrich({
    name: "가게",
  });

  assert.equal(result.kind[0].value, "파스타");
});
