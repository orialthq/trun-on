import assert from "node:assert/strict";
import test from "node:test";
import {
  addressMatches,
  nameMatches,
  selectResolvedPlace,
} from "../src/place_match.js";

const 페스카데리아 = {
  id: "1",
  name: "페스카데리아",
  address: "서울 성동구 성수동2가 315-13",
  roadAddress: "서울 성동구 연무장길 5",
  latitude: 37.5445,
  longitude: 127.0557,
};

test("matches a name ignoring spacing, case, and punctuation", () => {
  assert.equal(nameMatches("페스카데리아", "페스카데리아"), true);
  assert.equal(nameMatches(" 페스카 데리아 ", "페스카데리아"), true);
  assert.equal(nameMatches("Pescaderia", "PESCADERIA"), true);
  assert.equal(nameMatches("페스카데리아", "페스카테리아"), false);
});

test("accepts a branch suffix on the candidate but not a different shop", () => {
  assert.equal(nameMatches("페스카데리아", "페스카데리아 성수점"), true);
  assert.equal(nameMatches("페스카데리아", "페스카데리아 본점"), true);
  assert.equal(nameMatches("페스카데리아", "페스카데리아떡볶이"), false);
  // The reverse would let a captured long name collapse onto a shorter shop.
  assert.equal(nameMatches("페스카데리아 성수점", "페스카데리아"), false);
});

test("matches an address on a road plus building number when captured", () => {
  assert.equal(
    addressMatches("서울 성동구 연무장길 5", [페스카데리아.roadAddress]),
    true,
  );
  assert.equal(
    addressMatches("서울 성동구 연무장길 7", [페스카데리아.roadAddress]),
    false,
  );
});

test("matches an SNS area tag on its neighbourhood alone", () => {
  // Tags say 성수동 while address databases say 성수동2가.
  assert.equal(
    addressMatches("성수동", [페스카데리아.roadAddress, 페스카데리아.address]),
    true,
  );
  assert.equal(addressMatches("성수동2가", [페스카데리아.address]), true);
  assert.equal(addressMatches("성동구", [페스카데리아.roadAddress]), true);
  assert.equal(addressMatches("강남구", [페스카데리아.roadAddress]), false);
  assert.equal(addressMatches("연남동", [페스카데리아.address]), false);
});

test("treats region aliases as the same place", () => {
  assert.equal(addressMatches("서울특별시", ["서울 성동구 연무장길 5"]), true);
});

test("judges name and address independently", () => {
  const wrongNameRightAddress = {
    ...페스카데리아,
    id: "2",
    name: "다른가게",
  };
  // A convincing address must not carry a wrong name through.
  assert.equal(
    selectResolvedPlace({
      name: "페스카데리아",
      address: "서울 성동구 연무장길 5",
      candidates: [wrongNameRightAddress],
    }),
    null,
  );

  const rightNameWrongAddress = {
    ...페스카데리아,
    id: "3",
    address: "서울 강남구 역삼동 1",
    roadAddress: "서울 강남구 테헤란로 1",
  };
  assert.equal(
    selectResolvedPlace({
      name: "페스카데리아",
      address: "서울 성동구 연무장길 5",
      candidates: [rightNameWrongAddress],
    }),
    null,
  );
});

test("auto-confirms the single candidate matching every captured field", () => {
  const resolved = selectResolvedPlace({
    name: "페스카데리아",
    address: "성동구",
    candidates: [
      { ...페스카데리아, id: "9", name: "다른가게" },
      페스카데리아,
    ],
  });
  assert.equal(resolved?.id, "1");
});

test("refuses to choose between two candidates matching the same evidence", () => {
  const twin = { ...페스카데리아, id: "2" };
  assert.equal(
    selectResolvedPlace({
      name: "페스카데리아",
      address: "성동구",
      candidates: [페스카데리아, twin],
    }),
    null,
  );
});

test("requires at least one captured field to verify against", () => {
  assert.equal(
    selectResolvedPlace({ name: "", address: "", candidates: [페스카데리아] }),
    null,
  );
  assert.equal(
    selectResolvedPlace({ name: null, address: null, candidates: [] }),
    null,
  );
});

test("verifies on the name alone when no address was captured", () => {
  const resolved = selectResolvedPlace({
    name: "페스카데리아",
    address: null,
    candidates: [페스카데리아],
  });
  assert.equal(resolved?.id, "1");
});
