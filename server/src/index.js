import { createAnalysisService } from "./analysis_service.js";
import { createHttpServer } from "./http_app.js";
import { createKakaoTransport } from "./kakao_transport.js";
import { createOpenAITransport } from "./openai_transport.js";
import { createPlaceResolutionService } from "./place_resolution_service.js";

const apiKey = process.env.OPENAI_API_KEY;
if (!apiKey) {
  console.error(
    "OPENAI_API_KEY가 없습니다. `npm run dev`로 키체인에서 불러와 실행해 주세요.",
  );
  process.exitCode = 1;
} else {
  const transport = createOpenAITransport({ apiKey });
  const analysisService = createAnalysisService({ transport });

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

  const server = createHttpServer({ analysisService, placeResolutionService });

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
