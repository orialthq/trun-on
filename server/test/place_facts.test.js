import assert from "node:assert/strict";
import test from "node:test";
import { extractionItems } from "../src/extraction_prompt.js";
import { deriveFacts, canonicalTopic } from "../src/facts_derivation.js";
import { createPlaceFactsService } from "../src/place_facts_service.js";
import { createPlaceStore } from "../src/place_store.js";

// ── derivation ──────────────────────────────────────────────────────────────

const row = (topic, saidAt = "2026-07-01T00:00:00Z", quote = "인용") => ({
  source: "review",
  sourceId: `r-${Math.random()}`,
  topic,
  quote,
  saidAt,
});
const NOW = Date.parse("2026-08-10T00:00:00Z");

test("waiting bands follow the measured shops", () => {
  const derive = (rows) => deriveFacts({ place: null, evidence: rows, now: NOW }).filters.웨이팅;
  // 금돼지식당: queue reports only.
  assert.equal(derive(Array.from({ length: 5 }, () => row("현장줄"))), "상시 웨이팅");
  // 오레노라멘: weekend queues, weekday walk-ins — both true.
  assert.equal(derive([row("현장줄"), row("현장줄"), row("줄없음")]), "피크만 웨이팅");
  // 하동관: fast turnover, walked right in.
  assert.equal(derive([row("줄없음"), row("줄없음"), row("줄없음")]), "웨이팅 없음");
  // 어니언: two reports is not a verdict.
  assert.equal(derive([row("현장줄"), row("현장줄")]), null);
});

test("stale queue reports age out of the sample", () => {
  const derived = deriveFacts({
    place: null,
    evidence: [
      row("현장줄", "2023-01-01T00:00:00Z"),
      row("현장줄", "2023-02-01T00:00:00Z"),
      row("현장줄", "2023-03-01T00:00:00Z"),
    ],
    now: NOW,
  });
  assert.equal(derived.filters.웨이팅, null);
});

test("synonyms regroup at read time, not at write time", () => {
  assert.equal(canonicalTopic("웨이팅"), "현장줄");
  assert.equal(canonicalTopic("대기줄"), "현장줄");
  assert.equal(canonicalTopic("재료소진"), "재료소진");
  const derived = deriveFacts({
    place: null,
    evidence: [row("웨이팅"), row("대기줄"), row("오픈런")],
    now: NOW,
  });
  assert.equal(derived.filters.웨이팅, "상시 웨이팅");
});

test("price bands read Serper's own strings", () => {
  const band = (priceLevel) =>
    deriveFacts({ place: { priceLevel }, evidence: [], now: NOW }).filters.가격대;
  assert.equal(band("₩10,000~20,000"), "2만원 이하");
  assert.equal(band("₩20,000~60,000"), "2~5만원");
  assert.equal(band("₩100,000 이상"), "10만원 이상");
  assert.equal(band(null), null);
});

test("tips carry the long tail and skip filter topics", () => {
  const derived = deriveFacts({
    place: null,
    evidence: [
      row("재료소진", "2026-06-01T00:00:00Z", "재료소진 빨리 됨"),
      row("재료소진", "2026-07-01T00:00:00Z", "일찍 가야 먹음"),
      row("선불결제", "2026-05-01T00:00:00Z", "선불로 계산"),
      row("현장줄"),
      row("현장줄"),
      row("현장줄"),
    ],
    now: NOW,
  });
  assert.deepEqual(
    derived.tips.map((tip) => tip.topic),
    ["재료소진", "선불결제"],
  );
  // Two mentions, and the newer quote is the one shown.
  assert.equal(derived.tips[0].count, 2);
  assert.equal(derived.tips[0].quote, "일찍 가야 먹음");
});

// ── extraction parsing ──────────────────────────────────────────────────────

test("an invented quote does not survive extraction", () => {
  const texts = ["주말 웨이팅 1시간 정도 했습니다!", "주차는 유료입니다"];
  const items = extractionItems(
    {
      output_text: JSON.stringify({
        items: [
          { i: 0, t: "현장줄", q: "주말 웨이팅 1시간" },
          { i: 1, t: "주차유료", q: "발렛 5만원" }, // not in the review
          { i: 9, t: "현장줄", q: "주말 웨이팅 1시간" }, // no such review
        ],
      }),
    },
    texts,
  );
  assert.deepEqual(items, [{ index: 0, topic: "현장줄", quote: "주말 웨이팅 1시간" }]);
});

test("extraction reads a fenced answer with narration around it", () => {
  const texts = ["웨이팅 없이 바로 입장했어요"];
  const items = extractionItems(
    {
      output: [
        {
          type: "message",
          content: [
            { text: "분류 결과입니다.\n```json\n{\"items\":[{\"i\":0,\"t\":\"줄없음\",\"q\":\"웨이팅 없이 바로 입장했어요\"}]}\n```" },
          ],
        },
      ],
    },
    texts,
  );
  assert.equal(items.length, 1);
  assert.equal(items[0].topic, "줄없음");
});

// ── store ───────────────────────────────────────────────────────────────────

test("evidence is append-only and deduplicated", () => {
  const store = createPlaceStore();
  const item = { source: "review", sourceId: "r1", topic: "현장줄", quote: "줄 섰다" };
  store.addEvidence("f1", [item]);
  store.addEvidence("f1", [item]);
  assert.equal(store.evidenceFor("f1").length, 1);
  store.close();
});

test("processed reviews are remembered per place", () => {
  const store = createPlaceStore();
  store.markProcessed("f1", "review", ["r1", "r2"]);
  assert.deepEqual([...store.processedIds("f1", "review")].sort(), ["r1", "r2"]);
  assert.equal(store.processedIds("f2", "review").size, 0);
  store.close();
});

// ── service ─────────────────────────────────────────────────────────────────

function fakeSerper({ places, reviews }) {
  const calls = { maps: 0, reviews: 0, search: 0 };
  return {
    calls,
    async maps() {
      calls.maps += 1;
      return places;
    },
    async reviews() {
      calls.reviews += 1;
      return { reviews, nextPageToken: null };
    },
    async search() {
      calls.search += 1;
      return [];
    },
  };
}

const PLACE = Object.freeze({
  fid: "0x123",
  title: "금돼지식당",
  address: "서울 중구",
  latitude: 37.55,
  longitude: 127.01,
  type: "한국식 BBQ",
  priceLevel: "₩20,000~60,000",
  openingHours: { 월요일: "11:30~22:00" },
  bookingLinks: ["https://catchtable.example/kum"],
});
const REVIEWS = Object.freeze([
  { id: "r1", snippet: "주말 웨이팅 1시간 했습니다", isoDate: "2026-07-01T00:00:00Z" },
  { id: "r2", snippet: "오픈런해서 바로 먹음", isoDate: "2026-06-01T00:00:00Z" },
  { id: "r3", snippet: "대기 30분은 기본이에요", isoDate: "2026-05-01T00:00:00Z" },
]);

function extractionAnswer() {
  return {
    output_text: JSON.stringify({
      items: [
        { i: 0, t: "현장줄", q: "주말 웨이팅 1시간 했습니다" },
        { i: 1, t: "현장줄", q: "오픈런해서 바로 먹음" },
        { i: 2, t: "현장줄", q: "대기 30분은 기본이에요" },
      ],
    }),
  };
}

test("a first lookup fetches, extracts, stores, and derives", async () => {
  const serper = fakeSerper({ places: [PLACE], reviews: [...REVIEWS] });
  let extractions = 0;
  const service = createPlaceFactsService({
    serper,
    transport: {
      async createResponse() {
        extractions += 1;
        return extractionAnswer();
      },
    },
    model: "gpt-5.6-luna",
    store: createPlaceStore(),
  });

  const result = await service.lookup({ name: "금돼지식당", searchArea: "신당" });
  assert.equal(result.place.name, "금돼지식당");
  assert.equal(result.filters.웨이팅, "상시 웨이팅");
  assert.equal(result.filters.가격대, "2~5만원");
  assert.equal(result.fromStore, false);
  assert.equal(extractions, 1);
});

test("a second lookup answers from the store without spending", async () => {
  const serper = fakeSerper({ places: [PLACE], reviews: [...REVIEWS] });
  const service = createPlaceFactsService({
    serper,
    transport: { async createResponse() { return extractionAnswer(); } },
    model: "gpt-5.6-luna",
    store: createPlaceStore(),
  });

  await service.lookup({ name: "금돼지식당", searchArea: "신당" });
  const again = await service.lookup({ name: "금돼지식당", searchArea: "신당" });
  assert.equal(again.fromStore, true);
  assert.equal(again.filters.웨이팅, "상시 웨이팅");
  // The remembered resolution answers the repeat without any Serper call.
  assert.equal(serper.calls.maps, 1);
  assert.equal(serper.calls.reviews, 1);
});

test("a name mismatch attaches nothing", async () => {
  const serper = fakeSerper({
    places: [{ ...PLACE, title: "완전히 다른 가게" }],
    reviews: [...REVIEWS],
  });
  const service = createPlaceFactsService({
    serper,
    transport: { async createResponse() { return extractionAnswer(); } },
    model: "gpt-5.6-luna",
    store: createPlaceStore(),
  });

  const result = await service.lookup({ name: "금돼지식당", searchArea: "신당" });
  assert.equal(result.place, null);
  assert.equal(result.reason, "name_mismatch");
  assert.equal(serper.calls.reviews, 0);
});

test("extraction failure still answers from structured fields", async () => {
  const serper = fakeSerper({ places: [PLACE], reviews: [...REVIEWS] });
  const store = createPlaceStore();
  const service = createPlaceFactsService({
    serper,
    transport: { async createResponse() { throw new Error("upstream down"); } },
    model: "gpt-5.6-luna",
    store,
  });

  const result = await service.lookup({ name: "금돼지식당", searchArea: "신당" });
  assert.equal(result.filters.가격대, "2~5만원");
  assert.equal(result.filters.웨이팅, null);
  // Nothing was marked processed, so the next visit retries extraction.
  assert.equal(store.processedIds("0x123", "review").size, 0);
});

// ── maps candidate selection ────────────────────────────────────────────────

test("a chain needs the captured area to pick the branch", async (t) => {
  const { selectMapsPlace } = await import("../src/place_match.js");
  const candidates = [
    { fid: "a", title: "어니언 성수", address: "서울 성동구 아차산로9길 8" },
    { fid: "b", title: "어니언 미아", address: "서울 강북구 솔매로50길 55" },
  ];

  await t.test("colloquial area picks via the branch title", () => {
    assert.equal(selectMapsPlace({ name: "어니언", area: "성수", candidates }).place.fid, "a");
    assert.equal(selectMapsPlace({ name: "어니언", area: "미아", candidates }).place.fid, "b");
  });

  await t.test("a locality area picks via the address", () => {
    const branches = [
      { fid: "a", title: "하동관 명동본점", address: "서울 중구 명동9길 12" },
      { fid: "b", title: "하동관 코엑스점", address: "서울 강남구 영동대로 513" },
    ];
    assert.equal(selectMapsPlace({ name: "하동관", area: "명동", candidates: branches }).place.fid, "a");
  });

  // Area-named branches ("어니언 성수") are only recognisable as branches when
  // the captured area names one of them — without that, "어니언 성수" and a
  // hypothetical "어니언 베이커리" are indistinguishable, so both cases refuse
  // at the name axis rather than guessing.
  await t.test("no area on a chain refuses rather than guesses", () => {
    const picked = selectMapsPlace({ name: "어니언", area: "", candidates });
    assert.equal(picked.place, null);
  });

  await t.test("an area that fits neither branch refuses", () => {
    const picked = selectMapsPlace({ name: "어니언", area: "판교", candidates });
    assert.equal(picked.place, null);
  });
});

test("a lone name match is accepted even ranked second", async () => {
  const { selectMapsPlace } = await import("../src/place_match.js");
  const picked = selectMapsPlace({
    name: "금돼지식당",
    area: "신당",
    candidates: [
      { fid: "x", title: "완전히 다른 가게", address: "서울 어딘가" },
      { fid: "y", title: "금돼지식당", address: "서울 중구 다산로 149" },
    ],
  });
  assert.equal(picked.place.fid, "y");
});

test("an expired resolution goes back to live lookup", async () => {
  const serper = fakeSerper({ places: [PLACE], reviews: [...REVIEWS] });
  let clock = Date.parse("2026-08-01T00:00:00Z");
  const service = createPlaceFactsService({
    serper,
    transport: { async createResponse() { return extractionAnswer(); } },
    model: "gpt-5.6-luna",
    store: createPlaceStore(),
    now: () => clock,
  });

  await service.lookup({ name: "금돼지식당", searchArea: "신당" });
  clock += 31 * 24 * 3600 * 1000; // past both TTLs
  const later = await service.lookup({ name: "금돼지식당", searchArea: "신당" });
  assert.equal(later.fromStore, false);
  assert.equal(serper.calls.maps, 2);
});

test("identical-title duplicate records collapse to the rated one", async () => {
  const { selectMapsPlace } = await import("../src/place_match.js");
  const picked = selectMapsPlace({
    name: "남포면옥",
    area: "을지로",
    candidates: [
      { fid: "stale", title: "남포면옥", address: "서울 중구 을지로 124-1", latitude: 37.5661262, longitude: 126.9916862, ratingCount: 2 },
      { fid: "real", title: "남포면옥", address: "서울 중구 을지로3길 24", latitude: 37.567237, longitude: 126.9815378, ratingCount: 2280 },
    ],
  });
  assert.equal(picked.place.fid, "real");

  // Distinct branch titles must never collapse — that is a genuine ambiguity.
  const branches = selectMapsPlace({
    name: "어니언",
    area: "서울",
    candidates: [
      { fid: "a", title: "어니언 성수", address: "서울 성동구", latitude: 37.54, longitude: 127.05, ratingCount: 900 },
      { fid: "b", title: "어니언 미아", address: "서울 강북구", latitude: 37.62, longitude: 127.02, ratingCount: 800 },
    ],
  });
  assert.equal(branches.place, null);
});

test("a shop named after its area still discriminates branches", async () => {
  const { selectMapsPlace } = await import("../src/place_match.js");
  // The area word sits inside the shop name itself, so a whole-title area
  // check would match every branch; only the remainder may decide.
  const picked = selectMapsPlace({
    name: "광화문국밥",
    area: "광화문",
    candidates: [
      { fid: "main", title: "광화문국밥", address: "서울 중구 세종대로21길 53", latitude: 37.567, longitude: 126.977, ratingCount: 1838 },
      { fid: "branch", title: "광화문국밥 판교점", address: "경기 성남시 분당구", latitude: 37.39, longitude: 127.11, ratingCount: 210 },
    ],
  });
  // Neither remainder names 광화문, so the bare flagship title decides — a
  // capture naming just 광화문국밥 means the main shop, not the 판교 branch.
  assert.equal(picked.place.fid, "main");
  const single = selectMapsPlace({
    name: "광화문국밥",
    area: "광화문",
    candidates: [
      { fid: "main", title: "광화문국밥", address: "서울 중구 세종대로21길 53", latitude: 37.567, longitude: 126.977, ratingCount: 1838 },
    ],
  });
  assert.equal(single.place.fid, "main");
});

// ── platform notices ────────────────────────────────────────────────────────

test("platform snippets are extracted alongside reviews and stored as web evidence", async () => {
  const notice = {
    title: "부자피자 - 테이블링",
    link: "https://tabling.co.kr/restaurant/7943",
    snippet: "주말/공휴일은 원격줄서기를 하지않습니다!! 매장 앞 현장웨이팅만 가능하세요!!",
  };
  const serper = {
    calls: { search: 0 },
    async maps() { return [PLACE]; },
    async reviews() { return { reviews: [...REVIEWS], nextPageToken: null }; },
    async search(query) {
      serper.calls.search += 1;
      assert.match(query, /"금돼지식당" \(site:tabling\.co\.kr OR site:app\.catchtable\.co\.kr\)/);
      return [notice, { title: "무관한 블로그", link: "https://blog.example/1", snippet: "현장웨이팅만" }];
    },
  };
  const store = createPlaceStore();
  const service = createPlaceFactsService({
    serper,
    transport: {
      async createResponse(request) {
        const sent = request.input[0].content[0].text;
        // The notice text must have reached the same extraction pass.
        assert.match(sent, /현장웨이팅만 가능하세요/);
        return {
          output_text: JSON.stringify({
            items: [
              { i: 3, t: "현장대기", q: "매장 앞 현장웨이팅만 가능하세요!!" },
            ],
          }),
        };
      },
    },
    model: "gpt-5.6-luna",
    store,
  });

  const result = await service.lookup({ name: "금돼지식당", searchArea: "신당" });
  const webRows = store.evidenceFor("0x123").filter((row) => row.source === "web");
  assert.equal(webRows.length, 1);
  assert.equal(webRows[0].topic, "현장대기");
  assert.equal(webRows[0].sourceId, notice.link);
  // The off-platform blog row was filtered before extraction ever saw it as web
  // evidence, and the notice shows up as a tip.
  assert.ok(result.tips.some((tip) => tip.topic === "현장대기"));
});

test("a tabling listing alone answers 웨이팅 있음, and sentences outrank it", () => {
  const listed = { priceLevel: null, bookingLinks: ["https://tabling.co.kr/restaurant/1"] };
  const bare = deriveFacts({ place: listed, evidence: [], now: NOW });
  assert.equal(bare.filters.웨이팅, "웨이팅 있음");

  // Three walked-right-in reports beat the listing.
  const walkedIn = deriveFacts({
    place: listed,
    evidence: [row("줄없음"), row("줄없음"), row("줄없음")],
    now: NOW,
  });
  assert.equal(walkedIn.filters.웨이팅, "웨이팅 없음");

  const catchtableOnly = deriveFacts({
    place: { bookingLinks: ["https://app.catchtable.co.kr/ct/shop/x"] },
    evidence: [],
    now: NOW,
  });
  assert.equal(catchtableOnly.filters.웨이팅, null);
});
