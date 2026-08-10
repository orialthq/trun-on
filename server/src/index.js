import { createAnalysisService } from "./analysis_service.js";
import {
  DEEPSEEK_BASE_URL,
  DEEPSEEK_MODEL,
  DEEPSEEK_TIMEOUT_MS,
  MODEL,
} from "./constants.js";
import { createEnrichmentService } from "./enrichment_service.js";
import { createHttpServer } from "./http_app.js";
import { createKakaoTransport } from "./kakao_transport.js";
import { createOpenAITransport } from "./openai_transport.js";
import { createPlaceFactsService } from "./place_facts_service.js";
import { createPlaceResolutionService } from "./place_resolution_service.js";
import { createPlaceStore } from "./place_store.js";
import { createSerperTransport } from "./serper_transport.js";

const apiKey = process.env.OPENAI_API_KEY;
if (!apiKey) {
  console.error(
    "OPENAI_API_KEY가 없습니다. `npm run dev`로 키체인에서 불러와 실행해 주세요.",
  );
  process.exitCode = 1;
} else {
  const transport = createOpenAITransport({ apiKey });
  const analysisService = createAnalysisService({ transport });

  // The place lookup runs in two halves. Retrieval has to stay on this model
  // because it is the one whose search index reaches Korean listing sites — the
  // cheaper alternative returns Chinese travel pages for a Seoul restaurant.
  //
  // Judgment stays here too, which is not what the cheaper model was wired in
  // for. Measured on nine shops, three runs each, with identical excerpts:
  // reproducibility tied at 7/9 and every quote was real on both, but this model
  // answered in 2.6s against 19.4s and cost $0.0006 against $0.0009. The cheaper
  // per-token rate loses because it spends 2,241 reasoning tokens where this one
  // spends 113. Judgment is also only ~3% of the tokens a lookup uses; retrieval
  // is the other 97%, so the model choice here could not move the bill much
  // either way.
  //
  // The wiring stays because the comparison is worth repeating on other axes,
  // where a long structured answer might change the arithmetic. One env var.
  const judgeElsewhere =
    process.env.TRUN_ON_JUDGE_DEEPSEEK === "1" && process.env.DEEPSEEK_API_KEY;
  const enrichmentModel = judgeElsewhere ? DEEPSEEK_MODEL : MODEL;
  const enrichmentService = createEnrichmentService({
    retrievalTransport: transport,
    retrievalModel: MODEL,
    judgmentTransport: judgeElsewhere
      ? createOpenAITransport({
          apiKey: process.env.DEEPSEEK_API_KEY,
          baseUrl: DEEPSEEK_BASE_URL,
          timeoutMs: DEEPSEEK_TIMEOUT_MS,
        })
      : transport,
    judgmentModel: enrichmentModel,
    // Opt-in and local only, like the request logs. Counts only: how many
    // searches each probe needed, how many pages it opened, what it read. A
    // probe that searches more than once did not find it the first time.
    onSpend:
      process.env.TRUN_ON_DEBUG_LOG === "1"
        ? ({ query, probes }) => {
            const line = probes
              .map((p) =>
                p.failed
                  ? `${p.key}=실패`
                  : `${p.key}=검색${p.search}/열기${p.open}/찾기${p.find} in${p.input}`,
              )
              .join(" ");
            const searches = probes.reduce((sum, p) => sum + (p.search ?? 0), 0);
            console.log(`[spend] "${query}" ${line} → 검색 ${searches}회`);
            for (const p of probes) {
              for (const q of p.queries ?? []) console.log(`  [q] ${p.key}: ${q}`);
            }
          }
        : null,
  });
  console.log(`장소 보강 — 수집 ${MODEL} / 판단 ${enrichmentModel}`);

  // Place resolution is optional: without a key the app still analyses captures
  // and opens maps by text search.
  const kakaoKey = process.env.KAKAO_REST_API_KEY;
  const placeResolutionService = kakaoKey
    ? createPlaceResolutionService({
        transport: createKakaoTransport({ apiKey: kakaoKey }),
      })
    : null;
  if (!placeResolutionService) {
    console.warn(
      "KAKAO_REST_API_KEY가 없어 장소 정밀 검색은 비활성화됩니다.",
    );
  }

  // The facts pipeline: Serper for the place record and its reviews, one
  // extraction pass, a SQLite store of verbatim evidence, filters derived at
  // read time. Optional the same way resolution is — no key, no endpoint.
  const serperKey = process.env.SERPER_API_KEY;
  const placeFactsService = serperKey
    ? createPlaceFactsService({
        serper: createSerperTransport({ apiKey: serperKey }),
        transport,
        model: MODEL,
        // In memory for now, deliberately: at this stage a lookup re-buying its
        // $0.005 is cheaper than owning a database file with backups. The whole
        // store design (append-only evidence, derive-at-read) stays exercised,
        // and TRUN_ON_DB_PATH turns persistence on the day accumulation across
        // users starts to matter.
        store: createPlaceStore(
          process.env.TRUN_ON_DB_PATH ? { path: process.env.TRUN_ON_DB_PATH } : {},
        ),
      })
    : null;
  if (!placeFactsService) {
    console.warn("SERPER_API_KEY가 없어 장소 사실 조회는 비활성화됩니다.");
  }

  const server = createHttpServer({
    analysisService,
    enrichmentService,
    placeResolutionService,
    placeFactsService,
    enrichmentModel,
  });

  const host = process.env.HOST || "127.0.0.1";
  const port = parsePort(process.env.PORT);
  server.requestTimeout = 65_000;
  server.headersTimeout = 15_000;
  server.keepAliveTimeout = 5_000;

  server.listen(port, host, () => {
    const address = server.address();
    const resolvedPort =
      address && typeof address === "object" ? address.port : port;
    console.log(`Trun On analysis server: http://${host}:${resolvedPort}`);
  });

  const shutdown = () => server.close(() => process.exit(0));
  process.once("SIGINT", shutdown);
  process.once("SIGTERM", shutdown);
}

function parsePort(value) {
  if (value === undefined) {
    return 8787;
  }
  const port = Number(value);
  if (!Number.isInteger(port) || port < 0 || port > 65_535) {
    console.error("PORT는 0부터 65535 사이의 정수여야 합니다.");
    process.exit(1);
  }
  return port;
}
