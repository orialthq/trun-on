import {
  DEFAULT_MAX_IMAGE_BYTES,
  SUPPORTED_IMAGE_TYPES,
} from "./constants.js";
import { AppError } from "./errors.js";

const BASE64_PATTERN = /^[A-Za-z0-9+/]*={0,2}$/;
const LOCALE_PATTERN = /^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$/;

function isPlainObject(value) {
  return (
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    Object.getPrototypeOf(value) === Object.prototype
  );
}

function assertKeys(object, allowed, path) {
  const unknown = Object.keys(object).filter((key) => !allowed.has(key));
  if (unknown.length > 0) {
    throw new AppError(
      "INVALID_REQUEST",
      `${path}에 지원하지 않는 필드가 있어요.`,
      { httpStatus: 400 },
    );
  }
}

function validateOptionalString(value, path, maxLength) {
  if (value === undefined || value === null) {
    return;
  }
  if (typeof value !== "string" || value.length > maxLength) {
    throw new AppError(
      "INVALID_REQUEST",
      `${path} 형식이 올바르지 않아요.`,
      { httpStatus: 400 },
    );
  }
}

function decodedBase64ByteLength(base64) {
  const padding = base64.endsWith("==") ? 2 : base64.endsWith("=") ? 1 : 0;
  return (base64.length * 3) / 4 - padding;
}

function hasExpectedMagicBytes(buffer, mimeType) {
  if (mimeType === "image/jpeg") {
    return (
      buffer.length >= 3 &&
      buffer[0] === 0xff &&
      buffer[1] === 0xd8 &&
      buffer[2] === 0xff
    );
  }

  if (mimeType === "image/png") {
    return (
      buffer.length >= 8 &&
      buffer.subarray(0, 8).equals(
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      )
    );
  }

  if (mimeType === "image/webp") {
    return (
      buffer.length >= 12 &&
      buffer.subarray(0, 4).toString("ascii") === "RIFF" &&
      buffer.subarray(8, 12).toString("ascii") === "WEBP"
    );
  }

  return false;
}

export function validateEnrichPlaceRequest(body) {
  if (!isPlainObject(body)) {
    throw new AppError("INVALID_REQUEST", "요청 형식이 올바르지 않아요.", {
      httpStatus: 400,
    });
  }
  assertKeys(body, new Set(["name", "searchArea"]), "요청");
  validateOptionalString(body.name, "name", 120);
  validateOptionalString(body.searchArea, "searchArea", 40);

  const name = typeof body.name === "string" ? body.name.trim() : "";
  if (name === "") {
    throw new AppError("INVALID_REQUEST", "장소 이름이 필요해요.", {
      httpStatus: 400,
    });
  }
  const searchArea =
    typeof body.searchArea === "string" ? body.searchArea.trim() : "";
  return { name, searchArea: searchArea === "" ? null : searchArea };
}

export function validateResolvePlaceRequest(body) {
  if (!isPlainObject(body)) {
    throw new AppError("INVALID_REQUEST", "요청 형식이 올바르지 않아요.", {
      httpStatus: 400,
    });
  }
  assertKeys(body, new Set(["name", "address"]), "요청");

  const { name, address } = body;
  validateOptionalString(name, "name", 120);
  validateOptionalString(address, "address", 200);

  const trimmedName = typeof name === "string" ? name.trim() : "";
  const trimmedAddress = typeof address === "string" ? address.trim() : "";
  if (trimmedName === "" && trimmedAddress === "") {
    throw new AppError(
      "INVALID_REQUEST",
      "장소 이름이나 주소 중 하나는 필요해요.",
      { httpStatus: 400 },
    );
  }

  return {
    name: trimmedName === "" ? null : trimmedName,
    address: trimmedAddress === "" ? null : trimmedAddress,
  };
}

export function validateAnalyzeRequest(
  body,
  { maxImageBytes = DEFAULT_MAX_IMAGE_BYTES } = {},
) {
  if (!isPlainObject(body)) {
    throw new AppError(
      "INVALID_REQUEST",
      "요청 본문 형식이 올바르지 않아요.",
      { httpStatus: 400 },
    );
  }
  assertKeys(body, new Set(["image", "capture"]), "요청");

  if (!isPlainObject(body.image)) {
    throw new AppError(
      "INVALID_REQUEST",
      "image 정보가 필요해요.",
      { httpStatus: 400 },
    );
  }
  assertKeys(body.image, new Set(["mimeType", "base64"]), "image");

  const { mimeType, base64 } = body.image;
  if (typeof mimeType !== "string" || !SUPPORTED_IMAGE_TYPES.includes(mimeType)) {
    throw new AppError(
      "UNSUPPORTED_MEDIA_TYPE",
      "JPEG, PNG 또는 WEBP 이미지만 분석할 수 있어요.",
      { httpStatus: 415 },
    );
  }

  if (
    typeof base64 !== "string" ||
    base64.length === 0 ||
    base64.length % 4 !== 0 ||
    !BASE64_PATTERN.test(base64)
  ) {
    throw new AppError(
      "INVALID_IMAGE",
      "이미지 데이터 형식이 올바르지 않아요.",
      { httpStatus: 400 },
    );
  }

  const byteLength = decodedBase64ByteLength(base64);
  if (!Number.isInteger(byteLength) || byteLength <= 0) {
    throw new AppError(
      "INVALID_IMAGE",
      "이미지 데이터 형식이 올바르지 않아요.",
      { httpStatus: 400 },
    );
  }
  if (byteLength > maxImageBytes) {
    throw new AppError(
      "IMAGE_TOO_LARGE",
      "이미지 용량이 너무 커요.",
      { httpStatus: 413 },
    );
  }

  const decoded = Buffer.from(base64, "base64");
  if (decoded.length !== byteLength || !hasExpectedMagicBytes(decoded, mimeType)) {
    throw new AppError(
      "INVALID_IMAGE",
      "이미지 형식과 데이터가 일치하지 않아요.",
      { httpStatus: 400 },
    );
  }

  if (!isPlainObject(body.capture)) {
    throw new AppError(
      "INVALID_REQUEST",
      "capture 정보가 필요해요.",
      { httpStatus: 400 },
    );
  }
  assertKeys(
    body.capture,
    new Set(["id", "sourceApp", "sourceUrl", "capturedAt", "locale"]),
    "capture",
  );

  const { id, sourceApp, sourceUrl, capturedAt, locale } = body.capture;
  if (
    typeof id !== "string" ||
    id.trim().length === 0 ||
    id.length > 128
  ) {
    throw new AppError(
      "INVALID_REQUEST",
      "capture.id 형식이 올바르지 않아요.",
      { httpStatus: 400 },
    );
  }
  validateOptionalString(sourceApp, "capture.sourceApp", 64);
  validateOptionalString(sourceUrl, "capture.sourceUrl", 2_048);
  validateOptionalString(capturedAt, "capture.capturedAt", 64);
  validateOptionalString(locale, "capture.locale", 32);

  if (
    sourceUrl !== undefined &&
    sourceUrl !== null &&
    sourceUrl !== "" &&
    !isHttpUrl(sourceUrl)
  ) {
    throw new AppError(
      "INVALID_REQUEST",
      "capture.sourceUrl 형식이 올바르지 않아요.",
      { httpStatus: 400 },
    );
  }

  if (
    capturedAt !== undefined &&
    capturedAt !== null &&
    capturedAt !== "" &&
    Number.isNaN(Date.parse(capturedAt))
  ) {
    throw new AppError(
      "INVALID_REQUEST",
      "capture.capturedAt 형식이 올바르지 않아요.",
      { httpStatus: 400 },
    );
  }

  if (
    locale !== undefined &&
    locale !== null &&
    locale !== "" &&
    !LOCALE_PATTERN.test(locale)
  ) {
    throw new AppError(
      "INVALID_REQUEST",
      "capture.locale 형식이 올바르지 않아요.",
      { httpStatus: 400 },
    );
  }

  return {
    imageBase64: base64,
    mimeType,
    capture: {
      id: id.trim(),
      sourceApp: sourceApp || null,
      sourceUrl: sourceUrl || null,
      capturedAt: capturedAt || null,
      locale: locale || null,
    },
  };
}

function isHttpUrl(value) {
  try {
    const parsed = new URL(value);
    return parsed.protocol === "http:" || parsed.protocol === "https:";
  } catch {
    return false;
  }
}

/// The most a single recommendation call will carry.
///
/// The baseline sends everything the reader saved on purpose — deciding what to
/// leave out is exactly the kind of addition this is here to measure. But a
/// request still has to be bounded, so this is set well above any real library
/// and exists to stop a runaway payload, not to shape the answer.
const MAX_RECOMMENDATION_CANDIDATES = 300;

export function validatePlanRecommendationRequest(body) {
  if (!isPlainObject(body)) {
    throw new AppError("INVALID_REQUEST", "요청 형식이 올바르지 않아요.", {
      httpStatus: 400,
    });
  }
  assertKeys(body, new Set(["plan", "candidates"]), "요청");

  if (!isPlainObject(body.plan)) {
    throw new AppError("INVALID_REQUEST", "plan 정보가 필요해요.", {
      httpStatus: 400,
    });
  }
  assertKeys(body.plan, new Set(["title", "area", "scheduledAt"]), "plan");
  const title = typeof body.plan.title === "string" ? body.plan.title.trim() : "";
  if (title === "" || title.length > 200) {
    throw new AppError("INVALID_REQUEST", "plan.title이 필요해요.", {
      httpStatus: 400,
    });
  }
  validateOptionalString(body.plan.area, "plan.area", 200);
  validateOptionalString(body.plan.scheduledAt, "plan.scheduledAt", 64);

  if (!Array.isArray(body.candidates)) {
    throw new AppError("INVALID_REQUEST", "candidates가 필요해요.", {
      httpStatus: 400,
    });
  }
  if (body.candidates.length > MAX_RECOMMENDATION_CANDIDATES) {
    throw new AppError(
      "TOO_MANY_CANDIDATES",
      "한 번에 보낼 수 있는 후보 수를 넘었어요.",
      { httpStatus: 413 },
    );
  }

  const seen = new Set();
  const candidates = body.candidates.map((raw, index) => {
    if (!isPlainObject(raw)) {
      throw new AppError(
        "INVALID_REQUEST",
        `candidates[${index}] 형식이 올바르지 않아요.`,
        { httpStatus: 400 },
      );
    }
    assertKeys(
      raw,
      new Set([
        "id",
        "name",
        "folder",
        "area",
        "labels",
        "saveCount",
        "lastSavedAt",
      ]),
      `candidates[${index}]`,
    );
    const id = typeof raw.id === "string" ? raw.id.trim() : "";
    if (id === "" || id.length > 128) {
      throw new AppError(
        "INVALID_REQUEST",
        `candidates[${index}].id 형식이 올바르지 않아요.`,
        { httpStatus: 400 },
      );
    }
    // Duplicate ids would make an answer ambiguous — the caller could not tell
    // which of two identical rows was picked.
    if (seen.has(id)) {
      throw new AppError("INVALID_REQUEST", "candidates에 중복된 id가 있어요.", {
        httpStatus: 400,
      });
    }
    seen.add(id);

    const name = typeof raw.name === "string" ? raw.name.trim() : "";
    if (name === "" || name.length > 200) {
      throw new AppError(
        "INVALID_REQUEST",
        `candidates[${index}].name 형식이 올바르지 않아요.`,
        { httpStatus: 400 },
      );
    }
    validateOptionalString(raw.folder, `candidates[${index}].folder`, 64);
    validateOptionalString(raw.area, `candidates[${index}].area`, 120);
    validateOptionalString(
      raw.lastSavedAt,
      `candidates[${index}].lastSavedAt`,
      64,
    );

    let labels = [];
    if (raw.labels !== undefined && raw.labels !== null) {
      if (
        !Array.isArray(raw.labels) ||
        raw.labels.some(
          (label) => typeof label !== "string" || label.length > 60,
        )
      ) {
        throw new AppError(
          "INVALID_REQUEST",
          `candidates[${index}].labels 형식이 올바르지 않아요.`,
          { httpStatus: 400 },
        );
      }
      labels = raw.labels.map((label) => label.trim()).filter(Boolean);
    }

    let saveCount = 1;
    if (raw.saveCount !== undefined && raw.saveCount !== null) {
      if (!Number.isInteger(raw.saveCount) || raw.saveCount < 1) {
        throw new AppError(
          "INVALID_REQUEST",
          `candidates[${index}].saveCount 형식이 올바르지 않아요.`,
          { httpStatus: 400 },
        );
      }
      saveCount = raw.saveCount;
    }

    return {
      id,
      name,
      folder: raw.folder ?? null,
      area: raw.area ?? null,
      labels,
      saveCount,
      lastSavedAt: raw.lastSavedAt ?? null,
    };
  });

  return {
    plan: {
      title,
      area: body.plan.area?.trim() || null,
      scheduledAt: body.plan.scheduledAt ?? null,
    },
    candidates,
  };
}
