/// Deterministic matching between a captured place and a place-search candidate.
///
/// The captured name and the captured address are judged **independently**. A
/// candidate is only accepted when every field we actually captured matches on
/// its own axis, so a convincing address can never carry a wrong shop name (or
/// the reverse). Fields we did not capture impose no constraint.
///
/// Nothing here guesses. When no single candidate satisfies every captured
/// field, the caller is expected to leave the place unresolved rather than pin
/// the most plausible row.

/// Anchored at both ends because it is tested against the *remainder* after the
/// captured name, never against the whole candidate. Matching the whole string
/// would strip a name down to nothing.
const BRANCH_REMAINDER = /^[가-힣A-Za-z0-9]{1,10}점$/;

const REGION_ALIASES = new Map([
  ["서울특별시", "서울"],
  ["서울시", "서울"],
  ["부산광역시", "부산"],
  ["부산시", "부산"],
  ["대구광역시", "대구"],
  ["대구시", "대구"],
  ["인천광역시", "인천"],
  ["인천시", "인천"],
  ["광주광역시", "광주"],
  ["광주시", "광주"],
  ["대전광역시", "대전"],
  ["대전시", "대전"],
  ["울산광역시", "울산"],
  ["울산시", "울산"],
  ["세종특별자치시", "세종"],
  ["세종시", "세종"],
  ["경기도", "경기"],
  ["강원특별자치도", "강원"],
  ["강원도", "강원"],
  ["충청북도", "충북"],
  ["충청남도", "충남"],
  ["전북특별자치도", "전북"],
  ["전라북도", "전북"],
  ["전라남도", "전남"],
  ["경상북도", "경북"],
  ["경상남도", "경남"],
  ["제주특별자치도", "제주"],
  ["제주도", "제주"],
]);

/// `성수동2가` and `성수동` name the same neighbourhood. SNS tags use the short
/// form while address databases use the subdivided one, so localities compare on
/// their base form. Road names and building numbers still compare verbatim.
const NEIGHBOURHOOD_SUBDIVISION = /\d+가$/;

const ADMINISTRATIVE_TOKEN = /^[가-힣0-9]{1,12}(?:시|군|구)$/;
const NEIGHBOURHOOD_TOKEN = /^[가-힣0-9]{1,16}(?:읍|면|동|가|리)$/;
const ROAD_TOKEN = /^[가-힣0-9]{1,20}(?:대로|로|길)$/;
const BUILDING_NUMBER_TOKEN = /^\d+(?:-\d+)?$/;

/** Collapses spacing, punctuation, and case so two labels compare on content. */
export function normalizeName(value) {
  if (typeof value !== "string") return "";
  return value
    .replace(/<[^>]*>/g, "")
    .replace(/[\s]+/g, "")
    .replace(/[·・.,'"`\-_()[\]{}]/g, "")
    .toLowerCase();
}

/**
 * True when the candidate names the same business.
 *
 * Accepts an exact match, and a candidate that adds a branch suffix to the
 * captured name (`페스카데리아` vs `페스카데리아 성수점`). Does not accept the
 * reverse, because a captured name that merely extends a shorter candidate name
 * is usually a different business.
 */
export function nameMatches(capturedName, candidateName) {
  const captured = normalizeName(capturedName);
  const candidate = normalizeName(candidateName);
  if (!captured || !candidate) return false;
  if (captured === candidate) return true;
  if (!candidate.startsWith(captured)) return false;
  return BRANCH_REMAINDER.test(candidate.slice(captured.length));
}

function localityBase(token) {
  const base = token.replace(NEIGHBOURHOOD_SUBDIVISION, "");
  return base.length >= 2 ? base : token;
}

function normalizeAddressToken(token) {
  const cleaned = token.replace(/[^0-9A-Za-z가-힣-]/g, "");
  return REGION_ALIASES.get(cleaned) ?? cleaned;
}

function addressTokens(value) {
  if (typeof value !== "string") return [];
  return value
    .replace(/[,|·]+/g, " ")
    .split(/\s+/)
    .map(normalizeAddressToken)
    .filter((token) => token.length > 0);
}

/**
 * Splits a captured address into the parts that can be checked against a
 * candidate. A captured "address" is often an SNS location tag naming only a
 * neighbourhood, which is why the road and building number are optional.
 */
export function describeAddress(value) {
  const tokens = addressTokens(value);
  const regions = tokens.filter((token) => REGION_ALIASES.has(token) ||
    [...REGION_ALIASES.values()].includes(token));
  const administrative = tokens.filter((token) => ADMINISTRATIVE_TOKEN.test(token));
  const neighbourhoods = tokens.filter((token) => NEIGHBOURHOOD_TOKEN.test(token));

  let road = null;
  let buildingNumber = null;
  for (let index = 0; index < tokens.length; index += 1) {
    if (!ROAD_TOKEN.test(tokens[index])) continue;
    road = tokens[index];
    const next = tokens[index + 1];
    if (next && BUILDING_NUMBER_TOKEN.test(next)) {
      buildingNumber = next;
    }
    break;
  }

  return { tokens, regions, administrative, neighbourhoods, road, buildingNumber };
}

/**
 * True when the candidate sits at the captured location.
 *
 * The strictest captured signal wins: a road plus building number must appear
 * verbatim, otherwise a district or neighbourhood must appear. A captured
 * address with no recognisable locality imposes no constraint, because there is
 * nothing to verify and inventing one would defeat the point.
 */
export function addressMatches(capturedAddress, candidateAddresses) {
  const captured = describeAddress(capturedAddress);
  const candidateTokens = candidateAddresses
    .filter((value) => typeof value === "string" && value.length > 0)
    .flatMap(addressTokens);
  if (candidateTokens.length === 0) return false;

  const has = (token) => token !== null && candidateTokens.includes(token);
  const candidateLocalities = new Set(candidateTokens.map(localityBase));
  const hasLocality = (token) =>
    token !== null && candidateLocalities.has(localityBase(token));

  if (captured.road && captured.buildingNumber) {
    if (!has(captured.road) || !has(captured.buildingNumber)) return false;
    return true;
  }

  const localities = [...captured.neighbourhoods, ...captured.administrative];
  if (localities.length > 0) {
    return localities.some(hasLocality);
  }

  if (captured.regions.length > 0) {
    return captured.regions.some(has);
  }

  // No locality signal was captured, so there is nothing to contradict.
  return true;
}

/**
 * Picks the one candidate that matches every captured field, or null.
 *
 * Returning null is a normal outcome, not an error: it means the capture could
 * not be verified against a real place and the caller should keep searching by
 * text instead of pinning a coordinate the user never confirmed.
 */
export function selectResolvedPlace({ name, address, candidates }) {
  if (!Array.isArray(candidates) || candidates.length === 0) return null;

  const hasCapturedName = normalizeName(name).length > 0;
  const capturedAddress = typeof address === "string" ? address.trim() : "";

  // Nothing to verify against means nothing can be auto-confirmed.
  if (!hasCapturedName && capturedAddress.length === 0) return null;

  const accepted = candidates.filter((candidate) => {
    if (hasCapturedName && !nameMatches(name, candidate.name)) return false;
    if (
      capturedAddress.length > 0 &&
      !addressMatches(capturedAddress, [candidate.roadAddress, candidate.address])
    ) {
      return false;
    }
    return true;
  });

  // Two candidates satisfying the same evidence is an ambiguity, not a winner.
  return accepted.length === 1 ? accepted[0] : null;
}
