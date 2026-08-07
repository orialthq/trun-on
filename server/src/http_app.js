import { randomUUID } from "node:crypto";
import { createServer } from "node:http";
import {
  DEFAULT_BODY_TIMEOUT_MS,
  DEFAULT_MAX_BODY_BYTES,
  DEFAULT_MAX_IMAGE_BYTES,
  MODEL,
  SCHEMA_VERSION,
} from "./constants.js";
import { AppError, normalizeError } from "./errors.js";
import {
  validateAnalyzeRequest,
  validateEnrichPlaceRequest,
  validateResolvePlaceRequest,
} from "./request_validation.js";

export function createHttpServer({
  analysisService,
  enrichmentService = null,
  placeResolutionService = null,
  maxBodyBytes = DEFAULT_MAX_BODY_BYTES,
  maxImageBytes = DEFAULT_MAX_IMAGE_BYTES,
  bodyTimeoutMs = DEFAULT_BODY_TIMEOUT_MS,
} = {}) {
  if (!analysisService || typeof analysisService.analyze !== "function") {
    throw new Error("An analysisService is required");
  }
  if (
    placeResolutionService &&
    typeof placeResolutionService.resolve !== "function"
  ) {
    throw new Error("A placeResolutionService must expose resolve()");
  }
  if (enrichmentService && typeof enrichmentService.enrich !== "function") {
    throw new Error("An enrichmentService must expose enrich()");
  }

  return createServer(async (request, response) => {
    const requestId = randomUUID();
    setCommonHeaders(response, requestId);

    try {
      const url = new URL(request.url ?? "/", "http://localhost");

      if (url.pathname === "/health") {
        if (request.method !== "GET") {
          throw methodNotAllowed("GET");
        }
        return sendJson(response, 200, {
          status: "ok",
          service: "ori-capture-analysis",
          schemaVersion: SCHEMA_VERSION,
          model: MODEL,
        });
      }

      if (url.pathname === "/v1/analyze") {
        if (request.method !== "POST") {
          throw methodNotAllowed("POST");
        }
        assertJsonContentType(request.headers["content-type"]);
        const body = await readJsonBody(request, {
          maxBodyBytes,
          timeoutMs: bodyTimeoutMs,
        });
        const input = validateAnalyzeRequest(body, { maxImageBytes });
        const result = await analysisService.analyze(input);
        return sendJson(response, 200, result);
      }

      if (url.pathname === "/v1/enrich-place") {
        if (request.method !== "POST") {
          throw methodNotAllowed("POST");
        }
        if (!enrichmentService) {
          throw new AppError(
            "ENRICHMENT_NOT_CONFIGURED",
            "장소 보강을 사용할 수 없어요.",
            { httpStatus: 503 },
          );
        }
        assertJsonContentType(request.headers["content-type"]);
        const body = await readJsonBody(request, {
          maxBodyBytes: Math.min(maxBodyBytes, 8 * 1024),
          timeoutMs: bodyTimeoutMs,
        });
        const input = validateEnrichPlaceRequest(body);
        // Empty axes are a normal answer, so this is always a 200 when the
        // lookup ran at all.
        return sendJson(response, 200, await enrichmentService.enrich(input));
      }

      if (url.pathname === "/v1/resolve-place") {
        if (request.method !== "POST") {
          throw methodNotAllowed("POST");
        }
        if (!placeResolutionService) {
          throw new AppError(
            "PLACE_SEARCH_NOT_CONFIGURED",
            "장소 검색을 사용할 수 없어요.",
            { httpStatus: 503 },
          );
        }
        assertJsonContentType(request.headers["content-type"]);
        const body = await readJsonBody(request, {
          maxBodyBytes: Math.min(maxBodyBytes, 8 * 1024),
          timeoutMs: bodyTimeoutMs,
        });
        const input = validateResolvePlaceRequest(body);
        const resolution = await placeResolutionService.resolve(input);
        // A miss is a 200 with a null place. The client keeps its text search
        // instead of pinning a coordinate nobody verified.
        return sendJson(response, 200, {
          place: resolution.place,
          candidateCount: resolution.candidateCount,
        });
      }

      throw new AppError("NOT_FOUND", "요청한 경로를 찾을 수 없어요.", {
        httpStatus: 404,
      });
    } catch (error) {
      const normalized = normalizeError(error);
      return sendJson(response, normalized.httpStatus, {
        error: {
          code: normalized.code,
          message: normalized.message,
          retryable: normalized.retryable,
          requestId,
        },
      });
    }
  });
}

function setCommonHeaders(response, requestId) {
  response.setHeader("Content-Type", "application/json; charset=utf-8");
  response.setHeader("Cache-Control", "no-store");
  response.setHeader("X-Content-Type-Options", "nosniff");
  response.setHeader("X-Request-Id", requestId);
}

function sendJson(response, status, value) {
  if (response.writableEnded) {
    return;
  }
  response.statusCode = status;
  response.end(JSON.stringify(value));
}

function methodNotAllowed(allowedMethod) {
  return new AppError(
    "METHOD_NOT_ALLOWED",
    `${allowedMethod} 요청만 지원해요.`,
    { httpStatus: 405 },
  );
}

function assertJsonContentType(contentType) {
  if (
    typeof contentType !== "string" ||
    !contentType.toLowerCase().startsWith("application/json")
  ) {
    throw new AppError(
      "UNSUPPORTED_CONTENT_TYPE",
      "Content-Type은 application/json이어야 해요.",
      { httpStatus: 415 },
    );
  }
}

async function readJsonBody(request, { maxBodyBytes, timeoutMs }) {
  const contentLength = Number(request.headers["content-length"]);
  if (Number.isFinite(contentLength) && contentLength > maxBodyBytes) {
    throw new AppError("PAYLOAD_TOO_LARGE", "요청 용량이 너무 커요.", {
      httpStatus: 413,
    });
  }

  const chunks = [];
  let bytes = 0;
  let timer;

  try {
    const timeoutPromise = new Promise((_, reject) => {
      timer = setTimeout(
        () =>
          reject(
            new AppError(
              "REQUEST_TIMEOUT",
              "이미지 업로드 시간이 초과됐어요.",
              { httpStatus: 408, retryable: true },
            ),
          ),
        timeoutMs,
      );
      timer.unref?.();
    });

    const readPromise = (async () => {
      for await (const chunk of request) {
        bytes += chunk.length;
        if (bytes > maxBodyBytes) {
          throw new AppError(
            "PAYLOAD_TOO_LARGE",
            "요청 용량이 너무 커요.",
            { httpStatus: 413 },
          );
        }
        chunks.push(chunk);
      }
      return Buffer.concat(chunks).toString("utf8");
    })();

    const raw = await Promise.race([readPromise, timeoutPromise]);
    if (raw.length === 0) {
      throw new AppError(
        "INVALID_JSON",
        "JSON 요청 본문이 필요해요.",
        { httpStatus: 400 },
      );
    }
    try {
      return JSON.parse(raw);
    } catch (error) {
      throw new AppError(
        "INVALID_JSON",
        "JSON 형식이 올바르지 않아요.",
        { httpStatus: 400, cause: error },
      );
    }
  } finally {
    clearTimeout(timer);
  }
}
