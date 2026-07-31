export const MODEL = "gpt-5.6-luna";
export const SCHEMA_VERSION = "1.0";

export const DEFAULT_MAX_IMAGE_BYTES = 12 * 1024 * 1024;
export const DEFAULT_MAX_BODY_BYTES = 17 * 1024 * 1024;
export const DEFAULT_BODY_TIMEOUT_MS = 10_000;
export const DEFAULT_ANALYSIS_TIMEOUT_MS = 45_000;
export const DEFAULT_UPSTREAM_TIMEOUT_MS = 40_000;
export const DEFAULT_MAX_UPSTREAM_BODY_BYTES = 2 * 1024 * 1024;

export const SUPPORTED_IMAGE_TYPES = Object.freeze([
  "image/jpeg",
  "image/png",
  "image/webp",
]);
