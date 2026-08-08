import assert from "node:assert/strict";
import test from "node:test";
import { resolvePlaceIdentity } from "../src/place_identity.js";

const listings = (...names) =>
  names.map((nameOnPage, index) => ({
    url: `https://example.com/${index}`,
    nameOnPage,
    addressOnPage: null,
  }));

test("branch spellings of one shop are one shop", () => {
  // Retrieval really does return all four for 하동관. Treating them as four
  // rival candidates is what made a plain uniqueness check give up on a shop it
  // had already found.
  const resolved = resolvePlaceIdentity({
    name: "하동관",
    searchArea: "명동",
    listings: listings("하동관", "하동관 본점", "하동관 명동본점"),
  });

  assert.equal(resolved.resolvedName, "하동관");
  assert.deepEqual(resolved.aliases, ["하동관", "하동관 본점", "하동관 명동본점"]);
});

test("a different restaurant is refused, not resolved", () => {
  // Observed: a probe for 방콕테이블 came back with 샐몬 무쌉 twice.
  const resolved = resolvePlaceIdentity({
    name: "방콕테이블",
    searchArea: "용산구",
    listings: listings("샐몬 무쌉"),
  });

  assert.equal(resolved.resolvedName, null);
});

test("a page title is not a shop name", () => {
  const resolved = resolvePlaceIdentity({
    name: "화육계",
    searchArea: "을지로",
    listings: listings("화육계", "화육계 - 을지로3가 닭발, 계란말이 맛집"),
  });

  assert.equal(resolved.resolvedName, "화육계");
});

test("the captured area picks the branch of a chain", () => {
  const resolved = resolvePlaceIdentity({
    name: "어니언",
    searchArea: "성수",
    listings: listings("어니언 성수", "어니언 미아"),
  });

  assert.equal(resolved.resolvedName, "어니언 성수");
});

test("without an area a chain is refused rather than guessed", () => {
  // 성수 or 미아 is a coin flip, and a coin flip here shows the reader another
  // shop's hours as if they were verified.
  const resolved = resolvePlaceIdentity({
    name: "어니언",
    searchArea: null,
    listings: listings("어니언 성수", "어니언 미아"),
  });

  assert.equal(resolved.resolvedName, null);
});

test("two genuinely different shops are refused", () => {
  const resolved = resolvePlaceIdentity({
    name: "온천집",
    searchArea: null,
    listings: listings("온천집 강남", "온천집 부산"),
  });

  assert.equal(resolved.resolvedName, null);
});

test("no listings at all is a refusal", () => {
  assert.equal(
    resolvePlaceIdentity({ name: "가게", searchArea: "성수", listings: [] }).resolvedName,
    null,
  );
});

test("no captured name is a refusal", () => {
  assert.equal(
    resolvePlaceIdentity({ name: "  ", listings: listings("가게") }).resolvedName,
    null,
  );
});

test("the area never rescues a name that does not match", () => {
  // 성수 appearing in an unrelated shop's name must not promote it.
  const resolved = resolvePlaceIdentity({
    name: "어니언",
    searchArea: "성수",
    listings: listings("성수동 국밥"),
  });

  assert.equal(resolved.resolvedName, null);
});
