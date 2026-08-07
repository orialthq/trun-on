import assert from "node:assert/strict";
import test from "node:test";
import { PlaceSearchTransportError } from "../src/errors.js";
import { createKakaoTransport } from "../src/kakao_transport.js";

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

test("sends the keyword query with the REST key header", async () => {
  let receivedUrl;
  let receivedOptions;
  const transport = createKakaoTransport({
    apiKey: "test-only-key",
    fetchImpl: async (url, options) => {
      receivedUrl = new URL(url);
      receivedOptions = options;
      return jsonResponse({ documents: [] });
    },
  });

  await transport.searchKeyword("  페스카데리아 성수동  ");

  assert.equal(receivedUrl.host, "dapi.kakao.com");
  assert.equal(receivedUrl.pathname, "/v2/local/search/keyword.json");
  assert.equal(receivedUrl.searchParams.get("query"), "페스카데리아 성수동");
  assert.equal(receivedOptions.headers.Authorization, "KakaoAK test-only-key");
});

test("keeps only the fields needed to match and to pin", async () => {
  const transport = createKakaoTransport({
    apiKey: "test-only-key",
    fetchImpl: async () =>
      jsonResponse({
        documents: [
          {
            id: "12345",
            place_name: "페스카데리아",
            address_name: "서울 성동구 성수동2가 315-13",
            road_address_name: "서울 성동구 연무장길 5",
            category_group_name: "음식점",
            phone: "02-000-0000",
            x: "127.0557",
            y: "37.5445",
            place_url: "https://place.map.kakao.com/12345",
          },
        ],
      }),
  });

  const [candidate] = await transport.searchKeyword("페스카데리아");

  assert.deepEqual(candidate, {
    id: "12345",
    name: "페스카데리아",
    address: "서울 성동구 성수동2가 315-13",
    roadAddress: "서울 성동구 연무장길 5",
    category: "음식점",
    latitude: 37.5445,
    longitude: 127.0557,
    placeUrl: "https://place.map.kakao.com/12345",
  });
  assert.equal("phone" in candidate, false);
});

test("drops rows without usable coordinates", async () => {
  const transport = createKakaoTransport({
    apiKey: "test-only-key",
    fetchImpl: async () =>
      jsonResponse({
        documents: [
          { id: "1", place_name: "좌표없음", x: "", y: "" },
          { id: "2", place_name: "범위밖", x: "9999", y: "9999" },
          { id: "3", place_name: "정상", x: "127.0", y: "37.5" },
        ],
      }),
  });

  const candidates = await transport.searchKeyword("가게");
  assert.deepEqual(
    candidates.map((candidate) => candidate.id),
    ["3"],
  );
});

test("rejects a non-https place url", async () => {
  const transport = createKakaoTransport({
    apiKey: "test-only-key",
    fetchImpl: async () =>
      jsonResponse({
        documents: [
          {
            id: "1",
            place_name: "가게",
            x: "127.0",
            y: "37.5",
            place_url: "http://place.map.kakao.com/1",
          },
        ],
      }),
  });

  const [candidate] = await transport.searchKeyword("가게");
  assert.equal(candidate.placeUrl, null);
});

test("maps an unauthorized key to an authentication failure", async () => {
  const transport = createKakaoTransport({
    apiKey: "test-only-key",
    fetchImpl: async () => jsonResponse({ message: "denied" }, 401),
  });

  await assert.rejects(
    () => transport.searchKeyword("가게"),
    (error) =>
      error instanceof PlaceSearchTransportError &&
      error.kind === "authentication",
  );
});

test("maps a quota rejection to a retryable rate limit", async () => {
  const transport = createKakaoTransport({
    apiKey: "test-only-key",
    fetchImpl: async () => jsonResponse({ message: "quota" }, 429),
  });

  await assert.rejects(
    () => transport.searchKeyword("가게"),
    (error) =>
      error instanceof PlaceSearchTransportError &&
      error.kind === "rate_limited" &&
      error.retryable === true,
  );
});

test("returns nothing for a blank query without calling the API", async () => {
  let called = false;
  const transport = createKakaoTransport({
    apiKey: "test-only-key",
    fetchImpl: async () => {
      called = true;
      return jsonResponse({ documents: [] });
    },
  });

  assert.deepEqual(await transport.searchKeyword("   "), []);
  assert.equal(called, false);
});
