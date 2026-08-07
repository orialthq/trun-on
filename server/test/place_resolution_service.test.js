import assert from "node:assert/strict";
import test from "node:test";
import { createPlaceResolutionService } from "../src/place_resolution_service.js";

const 페스카데리아 = {
  id: "1",
  name: "페스카데리아",
  address: "서울 성동구 성수동2가 315-13",
  roadAddress: "서울 성동구 연무장길 5",
  category: "음식점",
  latitude: 37.5445,
  longitude: 127.0557,
  placeUrl: "https://place.map.kakao.com/1",
};

function transportReturning(byQuery) {
  const queries = [];
  return {
    queries,
    transport: {
      async searchKeyword(query) {
        queries.push(query);
        return byQuery[query] ?? [];
      },
    },
  };
}

test("searches name plus address first and stops once verified", async () => {
  const { queries, transport } = transportReturning({
    "페스카데리아 성수동": [페스카데리아],
  });
  const service = createPlaceResolutionService({ transport });

  const result = await service.resolve({
    name: "페스카데리아",
    address: "성수동",
  });

  assert.equal(result.place.id, "1");
  assert.deepEqual(queries, ["페스카데리아 성수동"]);
});

test("falls back to the name alone when the area tag finds nothing", async () => {
  const { queries, transport } = transportReturning({
    페스카데리아: [페스카데리아],
  });
  const service = createPlaceResolutionService({ transport });

  const result = await service.resolve({
    name: "페스카데리아",
    address: "성동구",
  });

  assert.equal(result.place.id, "1");
  assert.deepEqual(queries, ["페스카데리아 성동구", "페스카데리아"]);
});

test("resolves to nothing when no candidate matches every field", async () => {
  const { transport } = transportReturning({
    "페스카데리아 강남": [{ ...페스카데리아, name: "다른가게" }],
    페스카데리아: [{ ...페스카데리아, name: "다른가게" }],
  });
  const service = createPlaceResolutionService({ transport });

  const result = await service.resolve({
    name: "페스카데리아",
    address: "강남",
  });

  assert.equal(result.place, null);
  assert.equal(result.candidateCount, 1);
});

test("resolves to nothing when the search returns nothing", async () => {
  const { transport } = transportReturning({});
  const service = createPlaceResolutionService({ transport });

  const result = await service.resolve({ name: "없는가게", address: null });

  assert.equal(result.place, null);
  assert.equal(result.candidateCount, 0);
});

test("does not repeat an identical query", async () => {
  const { queries, transport } = transportReturning({});
  const service = createPlaceResolutionService({ transport });

  await service.resolve({ name: "가게", address: null });

  assert.deepEqual(queries, ["가게"]);
});

test("requires a transport", () => {
  assert.throws(() => createPlaceResolutionService({}), /transport is required/);
});
