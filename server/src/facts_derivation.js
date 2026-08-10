/// Filters are views, not data. Everything here is a pure function over stored
/// evidence rows, so a threshold or a synonym learned tomorrow re-labels every
/// place already in the store the moment this file changes.
///
/// The three filters are the ones discovery measured into the doc's "half true"
/// band across 21 shops: 웨이팅 57%, 가격대 57% of review text plus a
/// structured price level on 8-11/12 places, 주차 48%. Everything else the
/// extractor found stays browsable as tips.

/// Raw topic names normalise at read time — stored rows keep whatever the
/// extractor called them, so an entry added here regroups history for free.
const CANON = new Map([
  ["대기", "현장줄"], ["대기줄", "현장줄"], ["줄서기", "현장줄"], ["오픈런", "현장줄"],
  ["웨이팅", "현장줄"], ["대기등록", "현장줄"], ["대기마감", "현장줄"],
  ["주차", "주차가능"], ["주차장", "주차가능"], ["발렛", "주차유료"],
  ["발렛주차", "주차유료"], ["주차비", "주차유료"],
  ["예약경쟁", "예약난"], ["예약대기", "예약난"],
]);
export function canonicalTopic(topic) {
  return CANON.get(topic) ?? topic;
}

const FILTER_TOPICS = new Set(["현장줄", "줄없음", "예약난", "주차가능", "주차유료", "주차불가"]);
const RECENT_MS = 548 * 24 * 3600 * 1000; // 18 months: old queues fade, and so should their evidence.

export function deriveFacts({ place, evidence, now = Date.now() }) {
  const rows = evidence.map((row) => ({ ...row, topic: canonicalTopic(row.topic) }));
  return {
    filters: {
      가격대: priceBand(place?.priceLevel ?? null),
      웨이팅: waitingBand(rows, now) ?? waitingFromListing(place),
      주차: parking(rows),
    },
    tips: tips(rows),
  };
}

/// A shop on tabling pays for queue management, which no queue-less shop does —
/// the listing itself is evidence of "웨이팅 있음". It proves nothing beyond
/// that: whether the queue is remote-joinable is a per-shop toggle (금돼지식당
/// runs the app with 원격웨이팅 disabled), so the 원격/현장 distinction only
/// ever comes from sentences.
function waitingFromListing(place) {
  const links = Array.isArray(place?.bookingLinks) ? place.bookingLinks : [];
  return links.some((link) => typeof link === "string" && link.includes("tabling.co.kr"))
    ? "웨이팅 있음"
    : null;
}

/// 상시/피크만/없음 from the ratio of queue reports to walked-right-in reports.
/// Bands were fit on the measured shops: 금돼지 20:0 상시, 오레노라멘 5:3
/// 피크만 (weekend hour-long, weekday none — both true, so a binary label
/// would lie), 남포면옥 2:4 and 하동관 0:3 없음. Under three reports total the
/// honest answer is no label.
function waitingBand(rows, now) {
  const cutoff = now - RECENT_MS;
  const recent = rows.filter(
    (row) => !row.saidAt || Number.isNaN(Date.parse(row.saidAt)) || Date.parse(row.saidAt) > cutoff,
  );
  const queued = recent.filter((row) => row.topic === "현장줄").length;
  const walkedIn = recent.filter((row) => row.topic === "줄없음").length;
  const sample = queued + walkedIn;
  if (sample < 3) return null;
  const ratio = queued / sample;
  if (ratio >= 0.75) return "상시 웨이팅";
  if (ratio >= 0.35) return "피크만 웨이팅";
  return "웨이팅 없음";
}

/// Bands over Serper's own price strings ("₩20,000~60,000", "₩100,000 이상").
/// The midpoint decides — a 2만~6만 barbecue place is a 2~5만 answer to "얼마
/// 들고 가야 하나", not a 5~10만 one.
function priceBand(priceLevel) {
  if (typeof priceLevel !== "string") return null;
  const amounts = [...priceLevel.matchAll(/([\d,]+)/g)]
    .map((match) => Number(match[1].replaceAll(",", "")))
    .filter((amount) => Number.isFinite(amount) && amount >= 1_000);
  if (amounts.length === 0) return null;
  const mid =
    priceLevel.includes("이상")
      ? amounts[0]
      : amounts.reduce((sum, amount) => sum + amount, 0) / amounts.length;
  if (mid < 20_000) return "2만원 이하";
  if (mid < 50_000) return "2~5만원";
  if (mid < 100_000) return "5~10만원";
  return "10만원 이상";
}

function parking(rows) {
  const paid = rows.filter((row) => row.topic === "주차유료").length;
  const free = rows.filter((row) => row.topic === "주차가능").length;
  const none = rows.filter((row) => row.topic === "주차불가").length;
  if (paid + free + none === 0) return null;
  if (none > paid + free) return "주차 없음";
  return paid >= free ? "주차 유료·발렛" : "주차 가능";
}

/// The long tail is the point: topics that never became a filter — 재료소진,
/// 선불결제, 일행동반 입장 — answer "가기로 했으면 뭘 알아야 하나" better than
/// any label. Grouped by topic, newest quote wins, capped so the card stays a
/// card.
function tips(rows) {
  const byTopic = new Map();
  for (const row of rows) {
    if (FILTER_TOPICS.has(row.topic)) continue;
    const previous = byTopic.get(row.topic);
    if (!previous || (row.saidAt ?? "") > (previous.saidAt ?? "")) byTopic.set(row.topic, row);
    byTopic.get(row.topic).count = (previous?.count ?? 0) + 1;
  }
  return [...byTopic.values()]
    .sort((a, b) => b.count - a.count || (b.saidAt ?? "").localeCompare(a.saidAt ?? ""))
    .slice(0, 8)
    .map((row) => ({ topic: row.topic, quote: row.quote, saidAt: row.saidAt ?? null, count: row.count }));
}
