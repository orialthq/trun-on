import assert from "node:assert/strict";
import test from "node:test";
import { createEnrichmentService } from "../src/enrichment_service.js";

/// A retrieval reply carries a search tool; a judgment reply does not. The fakes
/// below answer whichever half asked, and record both so a test can assert that
/// judgment never ran.
function transportFor({ retrieval = [], judgment = null } = {}) {
  const retrievals = [];
  const judgments = [];
  let index = 0;
  return {
    retrievals,
    judgments,
    transport: {
      async createResponse(body) {
        const isRetrieval = Array.isArray(body.tools) && body.tools.length > 0;
        if (isRetrieval) {
          retrievals.push(body);
          const reply = retrieval[Math.min(index++, retrieval.length - 1)] ?? {
            listings: [],
            excerpts: [],
          };
          return { status: "completed", output_text: JSON.stringify(reply) };
        }
        judgments.push(body);
        if (judgment === null) {
          return { status: "completed", output_text: "찾지 못했습니다." };
        }
        return {
          status: "completed",
          output_text:
            typeof judgment === "string" ? judgment : JSON.stringify(judgment),
        };
      },
    },
  };
}

const listing = (nameOnPage, url = "https://www.diningcode.com/profile.php?rid=A") => ({
  url,
  nameOnPage,
  addressOnPage: null,
});
const excerpt = (text, url = "https://www.diningcode.com/profile.php?rid=A") => ({
  url,
  text,
});
const label = (value, quote, citations, confidence = 0.8) => ({
  quote,
  value,
  confidence,
  citations,
});

const enrich = (setup, input = { name: "가게", searchArea: "성수" }) => {
  const made = transportFor(setup);
  return { made, result: createEnrichmentService({ transport: made.transport }).enrich(input) };
};

test("every probe runs, and each carries the shop name with its area", async () => {
  const made = transportFor({
    retrieval: [{ listings: [listing("가게")], excerpts: [excerpt("예약 가능")] }],
  });

  await createEnrichmentService({ transport: made.transport }).enrich({
    name: "가게",
    searchArea: "성수",
  });

  // Three probes: the listing sites, the booking platforms, and the open web.
  assert.equal(made.retrievals.length, 3);
  for (const body of made.retrievals) {
    assert.match(JSON.stringify(body.input), /가게 성수/);
    assert.equal(body.tools[0].type, "web_search");
  }
  const restricted = made.retrievals.filter((b) => b.tools[0].filters);
  assert.equal(restricted.length, 2);
});

test("retrieval asks for sentences and never for a label", async () => {
  const made = transportFor({ retrieval: [{ listings: [], excerpts: [] }] });

  await createEnrichmentService({ transport: made.transport }).enrich({ name: "가게" });

  const instructions = made.retrievals[0].instructions;
  assert.match(instructions, /You retrieve\. You do not interpret\./);
  // The axis vocabulary must not leak into the retrieval half, or it starts
  // deciding and the split stops meaning anything.
  assert.doesNotMatch(instructions, /예약 필수|웨이팅 있음/);
});

test("an unresolvable shop is never judged", async () => {
  // The listing is a different restaurant. Attaching its hours to this capture
  // is the one failure worse than having no hours, so the lookup stops here.
  const made = transportFor({
    retrieval: [{ listings: [listing("샐몬 무쌉")], excerpts: [excerpt("예약 가능")] }],
    judgment: { matchedName: "샐몬 무쌉", kind: [], access: [label("예약 가능", "예약 가능", ["https://www.diningcode.com/profile.php?rid=A"])] },
  });

  const result = await createEnrichmentService({ transport: made.transport }).enrich({
    name: "방콕테이블",
    searchArea: "용산구",
  });

  assert.equal(made.judgments.length, 0);
  assert.equal(result.matchedName, null);
  assert.deepEqual(result.access, []);
});

test("branch spellings of one shop resolve to that shop", async () => {
  const made = transportFor({
    retrieval: [
      {
        listings: [listing("하동관"), listing("하동관 본점"), listing("하동관 명동본점")],
        excerpts: [excerpt("편의시설 Take out, 예약 가능, 주차장 있음")],
      },
    ],
    judgment: {
      matchedName: "하동관",
      kind: [],
      access: [
        label("예약 가능", "편의시설 Take out, 예약 가능, 주차장 있음", [
          "https://www.diningcode.com/profile.php?rid=A",
        ]),
      ],
    },
  });

  const result = await createEnrichmentService({ transport: made.transport }).enrich({
    name: "하동관",
    searchArea: "명동",
  });

  // Three retrievals, one judgment: the probes fan out, the decision does not.
  assert.equal(made.retrievals.length, 3);
  assert.equal(made.judgments.length, 1);
  assert.equal(result.access[0].value, "예약 가능");
});

test("the judging half is handed sentences and no search tool", async () => {
  const made = transportFor({
    retrieval: [{ listings: [listing("가게")], excerpts: [excerpt("예약 가능")] }],
    judgment: { matchedName: "가게", kind: [], access: [] },
  });

  await createEnrichmentService({ transport: made.transport }).enrich({ name: "가게" });

  const body = made.judgments[0];
  assert.equal(body.tools, undefined);
  assert.match(JSON.stringify(body.input), /예약 가능/);
  // Thinking stays on: with it off, three runs of one bundle agreed a quarter of
  // the time and the forbidden 웨이팅 cases came back.
  assert.equal(body.reasoning.effort, "low");
});

test("a quote that is not in the excerpts is dropped", async () => {
  // The retrieval half is the record of what the pages said. A label quoting
  // something that is not in it invented its evidence.
  const made = transportFor({
    retrieval: [{ listings: [listing("가게")], excerpts: [excerpt("영업시간: 11:00 - 22:00")] }],
    judgment: {
      matchedName: "가게",
      kind: [],
      access: [label("예약 필수", "예약은 필수입니다", ["https://www.diningcode.com/profile.php?rid=A"])],
    },
  });

  const result = await createEnrichmentService({ transport: made.transport }).enrich({
    name: "가게",
  });

  assert.deepEqual(result.access, []);
});

test("a citation the retrieval half never returned is not a source", async () => {
  const made = transportFor({
    retrieval: [{ listings: [listing("가게")], excerpts: [excerpt("예약 가능")] }],
    judgment: {
      matchedName: "가게",
      kind: [],
      access: [label("예약 가능", "예약 가능", ["https://invented.example.com/1"])],
    },
  });

  const result = await createEnrichmentService({ transport: made.transport }).enrich({
    name: "가게",
  });

  assert.deepEqual(result.access, []);
});

test("a value outside the closed vocabulary is dropped", async () => {
  const made = transportFor({
    retrieval: [{ listings: [listing("가게")], excerpts: [excerpt("워크인 환영")] }],
    judgment: {
      matchedName: "가게",
      kind: [],
      access: [label("워크인 환영", "워크인 환영", ["https://www.diningcode.com/profile.php?rid=A"])],
    },
  });

  const result = await createEnrichmentService({ transport: made.transport }).enrich({
    name: "가게",
  });

  assert.deepEqual(result.access, []);
});

test("one place cannot both require and refuse a booking", async () => {
  const url = "https://www.diningcode.com/profile.php?rid=A";
  const made = transportFor({
    retrieval: [{ listings: [listing("가게")], excerpts: [excerpt("예약제"), excerpt("예약을 받지 않습니다")] }],
    judgment: {
      matchedName: "가게",
      kind: [],
      access: [label("예약 필수", "예약제", [url]), label("예약 없이", "예약을 받지 않습니다", [url])],
    },
  });

  const result = await createEnrichmentService({ transport: made.transport }).enrich({
    name: "가게",
  });

  assert.deepEqual(
    result.access.map((entry) => entry.value),
    ["예약 필수"],
  );
});

test("bookings and a queue can both be true of one place", async () => {
  const url = "https://www.diningcode.com/profile.php?rid=A";
  const made = transportFor({
    retrieval: [{ listings: [listing("가게")], excerpts: [excerpt("네이버 예약 가능"), excerpt("늘 줄이 길다")] }],
    judgment: {
      matchedName: "가게",
      kind: [],
      access: [label("예약 가능", "네이버 예약 가능", [url]), label("웨이팅 있음", "늘 줄이 길다", [url])],
    },
  });

  const result = await createEnrichmentService({ transport: made.transport }).enrich({
    name: "가게",
  });

  assert.deepEqual(
    result.access.map((entry) => entry.value),
    ["예약 가능", "웨이팅 있음"],
  );
});

test("a page on a booking platform settles the booking question in code", async () => {
  // Its existence is the evidence. Asking a model to read a sentence about it
  // would only add a way to get it wrong.
  const made = transportFor({
    retrieval: [
      {
        listings: [listing("화육계", "https://www.tabling.co.kr/restaurant/4576")],
        excerpts: [excerpt("단체석 구비", "https://www.siksinhot.com/P/1")],
      },
    ],
    judgment: { matchedName: "화육계", kind: [], access: [] },
  });

  const result = await createEnrichmentService({ transport: made.transport }).enrich({
    name: "화육계",
    searchArea: "을지로",
  });

  assert.equal(result.access[0].value, "예약 가능");
  assert.deepEqual(result.access[0].citations, ["https://www.tabling.co.kr/restaurant/4576"]);
});

test("a booking platform page never downgrades a stated 예약 필수", async () => {
  const made = transportFor({
    retrieval: [
      {
        listings: [listing("가게", "https://www.catchtable.co.kr/place/1")],
        excerpts: [excerpt("예약제로 운영합니다", "https://www.diningcode.com/profile.php?rid=A")],
      },
    ],
    judgment: {
      matchedName: "가게",
      kind: [],
      access: [
        label("예약 필수", "예약제로 운영합니다", ["https://www.diningcode.com/profile.php?rid=A"]),
      ],
    },
  });

  const result = await createEnrichmentService({ transport: made.transport }).enrich({
    name: "가게",
  });

  assert.deepEqual(
    result.access.map((entry) => entry.value),
    ["예약 필수"],
  );
});

test("an answer buried in narration and a fence is still read", async () => {
  const url = "https://www.diningcode.com/profile.php?rid=A";
  const answer = {
    matchedName: "가게",
    kind: [],
    access: [label("예약 없이", "예약을 받지 않습니다", [url])],
  };
  const made = transportFor({
    retrieval: [{ listings: [listing("가게")], excerpts: [excerpt("예약을 받지 않습니다")] }],
    judgment: `알겠습니다. 정리하겠습니다.\n\n\`\`\`json\n${JSON.stringify(answer)}\n\`\`\``,
  });

  const result = await createEnrichmentService({ transport: made.transport }).enrich({
    name: "가게",
  });

  assert.equal(result.access[0].value, "예약 없이");
});

test("a judging reply with no object at all is retried once", async () => {
  const url = "https://www.diningcode.com/profile.php?rid=A";
  const answer = {
    matchedName: "가게",
    kind: [],
    access: [label("예약 가능", "예약 가능", [url])],
  };
  let judgments = 0;
  const transport = {
    async createResponse(body) {
      if (Array.isArray(body.tools) && body.tools.length > 0) {
        return {
          status: "completed",
          output_text: JSON.stringify({
            listings: [listing("가게")],
            excerpts: [excerpt("예약 가능")],
          }),
        };
      }
      judgments++;
      // Prose with no object the first time, the answer on the retry.
      if (judgments === 1) {
        return { status: "completed", output_text: "확인 중입니다." };
      }
      return { status: "completed", output_text: JSON.stringify(answer) };
    },
  };

  const result = await createEnrichmentService({ transport }).enrich({ name: "가게" });

  assert.ok(judgments >= 2, "재시도가 있어야 한다");
  assert.equal(result.access[0].value, "예약 가능");
});

test("a shop with no excerpts is an empty answer, not an error", async () => {
  const made = transportFor({ retrieval: [{ listings: [], excerpts: [] }] });

  const result = await createEnrichmentService({ transport: made.transport }).enrich({
    name: "존재하지않는가게",
  });

  assert.deepEqual(result, { matchedName: null, kind: [], access: [] });
  assert.equal(made.judgments.length, 0);
});

test("skips every call without a name", async () => {
  const made = transportFor({ retrieval: [{ listings: [], excerpts: [] }] });

  const result = await createEnrichmentService({ transport: made.transport }).enrich({
    name: "   ",
    searchArea: "성수",
  });

  assert.equal(made.retrievals.length, 0);
  assert.deepEqual(result.kind, []);
});

test("the judging half can run on a different provider", async () => {
  const retrieval = transportFor({
    retrieval: [{ listings: [listing("가게")], excerpts: [excerpt("예약 가능")] }],
  });
  const judgments = [];
  const judgment = {
    async createResponse(body) {
      judgments.push(body);
      return { status: "completed", output_text: JSON.stringify({ matchedName: "가게", kind: [], access: [] }) };
    },
  };

  await createEnrichmentService({
    retrievalTransport: retrieval.transport,
    retrievalModel: "gpt-5.6-luna",
    judgmentTransport: judgment,
    judgmentModel: "deepseek-v4-flash",
  }).enrich({ name: "가게" });

  assert.equal(retrieval.retrievals[0].model, "gpt-5.6-luna");
  assert.equal(judgments[0].model, "deepseek-v4-flash");
});

test("the same sentence from two probes is stored once", async () => {
  const made = transportFor({
    retrieval: [
      { listings: [listing("가게")], excerpts: [excerpt("예약 가능"), excerpt("예약 가능")] },
    ],
    judgment: { matchedName: "가게", kind: [], access: [] },
  });

  await createEnrichmentService({ transport: made.transport }).enrich({ name: "가게" });

  const handed = JSON.stringify(made.judgments[0].input);
  assert.equal(handed.split("예약 가능").length - 1, 1);
});

test("each probe asks for what its own query names", async () => {
  const made = transportFor({
    retrieval: [{ listings: [listing("가게")], excerpts: [excerpt("웨이팅 있음")] }],
    judgment: { matchedName: "가게", kind: [], access: [] },
  });

  await createEnrichmentService({
    transport: made.transport,
    probes: [
      { key: "listing", suffix: "", allowedDomains: null },
      { key: "experience", suffix: "웨이팅 대기 줄", allowedDomains: null },
    ],
  }).enrich({ name: "가게", searchArea: "성수" });

  const asked = made.retrievals.map((body) => body.input[0].content[0].text);
  assert.match(asked[0], /가게: 가게 성수/);
  assert.doesNotMatch(asked[0], /찾을 것/);
  assert.match(asked[1], /찾을 것: 웨이팅 대기 줄/);
  // The suffix must not reach the name that identity resolution matches on.
  assert.match(asked[1], /가게: 가게 성수\n/);
});

test("reports what each probe searched, even when it came back empty", async () => {
  const spends = [];
  const transport = {
    async createResponse(body) {
      if (!Array.isArray(body.tools) || body.tools.length === 0) {
        return { status: "completed", output_text: "찾지 못했습니다." };
      }
      return {
        status: "completed",
        output: [
          { type: "web_search_call", action: { type: "search", query: "가게 성수" } },
          { type: "web_search_call", action: { type: "search", query: "가게 성수 웨이팅" } },
          { type: "web_search_call", action: { type: "open_page" } },
          { type: "web_search_call", action: { type: "find_in_page" } },
          { type: "message", content: [{ text: JSON.stringify({ listings: [], excerpts: [] }) }] },
        ],
        usage: { input_tokens: 18_432, output_tokens: 612 },
      };
    },
  };

  await createEnrichmentService({
    transport,
    probes: [{ key: "listing", suffix: "", allowedDomains: null }],
    onSpend: (spend) => spends.push(spend),
  }).enrich({ name: "가게", searchArea: "성수" });

  assert.equal(spends.length, 1);
  assert.equal(spends[0].query, "가게 성수");
  assert.deepEqual(spends[0].probes, [
    {
      key: "listing",
      search: 2,
      open: 1,
      find: 1,
      input: 18_432,
      output: 612,
      reasoning: 0,
      // The query is the model's, not ours, so a probe that found nothing can be
      // told apart from one that asked the wrong question.
      queries: ["가게 성수", "가게 성수 웨이팅"],
    },
  ]);
});

test("a probe that failed outright is still reported", async () => {
  const spends = [];
  const transport = {
    async createResponse(body) {
      if (Array.isArray(body.tools) && body.tools.length > 0) {
        throw new Error("upstream is down");
      }
      return { status: "completed", output_text: "찾지 못했습니다." };
    },
  };

  await createEnrichmentService({
    transport,
    probes: [{ key: "booking", suffix: "예약", allowedDomains: null }],
    onSpend: (spend) => spends.push(spend),
  }).enrich({ name: "가게" });

  assert.deepEqual(spends[0].probes, [{ key: "booking", failed: true }]);
});
