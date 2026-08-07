export class AppError extends Error {
  constructor(code, message, options = {}) {
    super(message, { cause: options.cause });
    this.name = "AppError";
    this.code = code;
    this.httpStatus = options.httpStatus ?? 500;
    this.retryable = options.retryable ?? false;
  }
}

export class OpenAITransportError extends Error {
  constructor(kind, options = {}) {
    super(kind, { cause: options.cause });
    this.name = "OpenAITransportError";
    this.kind = kind;
    this.upstreamStatus = options.upstreamStatus ?? null;
    this.retryable = options.retryable ?? false;
  }
}

export class PlaceSearchTransportError extends Error {
  constructor(kind, options = {}) {
    super(kind, { cause: options.cause });
    this.name = "PlaceSearchTransportError";
    this.kind = kind;
    this.upstreamStatus = options.upstreamStatus ?? null;
    this.retryable = options.retryable ?? false;
  }
}

export function normalizeError(error) {
  if (error instanceof AppError) {
    return error;
  }

  if (error instanceof OpenAITransportError) {
    switch (error.kind) {
      case "timeout":
        return new AppError(
          "UPSTREAM_TIMEOUT",
          "분석 시간이 초과됐어요. 잠시 후 다시 시도해 주세요.",
          { httpStatus: 504, retryable: true, cause: error },
        );
      case "rate_limited":
        return new AppError(
          "UPSTREAM_RATE_LIMITED",
          "분석 요청이 많아요. 잠시 후 다시 시도해 주세요.",
          { httpStatus: 429, retryable: true, cause: error },
        );
      case "authentication":
        return new AppError(
          "SERVICE_NOT_CONFIGURED",
          "분석 서비스를 사용할 수 없어요.",
          { httpStatus: 503, retryable: false, cause: error },
        );
      case "rejected":
        return new AppError(
          "UPSTREAM_REJECTED",
          "이 이미지는 분석할 수 없어요.",
          { httpStatus: 422, retryable: false, cause: error },
        );
      case "invalid_response":
        return new AppError(
          "INVALID_MODEL_RESPONSE",
          "분석 결과를 확인할 수 없어요. 다시 시도해 주세요.",
          { httpStatus: 502, retryable: true, cause: error },
        );
      default:
        return new AppError(
          "UPSTREAM_UNAVAILABLE",
          "분석 서비스에 연결할 수 없어요. 잠시 후 다시 시도해 주세요.",
          {
            httpStatus: 502,
            retryable: error.retryable,
            cause: error,
          },
        );
    }
  }

  if (error instanceof PlaceSearchTransportError) {
    // A place lookup that fails is not a failed capture: the caller falls back to
    // a text map search, so these stay distinct from the analysis error codes.
    switch (error.kind) {
      case "timeout":
        return new AppError(
          "PLACE_SEARCH_TIMEOUT",
          "장소를 찾는 데 시간이 오래 걸려요. 잠시 후 다시 시도해 주세요.",
          { httpStatus: 504, retryable: true, cause: error },
        );
      case "rate_limited":
        return new AppError(
          "PLACE_SEARCH_RATE_LIMITED",
          "장소 검색 요청이 많아요. 잠시 후 다시 시도해 주세요.",
          { httpStatus: 429, retryable: true, cause: error },
        );
      case "authentication":
        return new AppError(
          "PLACE_SEARCH_NOT_CONFIGURED",
          "장소 검색을 사용할 수 없어요.",
          { httpStatus: 503, retryable: false, cause: error },
        );
      default:
        return new AppError(
          "PLACE_SEARCH_UNAVAILABLE",
          "장소 검색에 연결할 수 없어요. 잠시 후 다시 시도해 주세요.",
          { httpStatus: 502, retryable: error.retryable, cause: error },
        );
    }
  }

  if (error?.name === "AbortError" || error?.name === "TimeoutError") {
    return new AppError(
      "UPSTREAM_TIMEOUT",
      "분석 시간이 초과됐어요. 잠시 후 다시 시도해 주세요.",
      { httpStatus: 504, retryable: true, cause: error },
    );
  }

  return new AppError(
    "INTERNAL_ERROR",
    "요청을 처리하지 못했어요.",
    { httpStatus: 500, retryable: false, cause: error },
  );
}
