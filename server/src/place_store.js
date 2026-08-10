import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";

/// The store is the architecture. Facts are kept as the sentences that carried
/// them — topic, verbatim quote, source, date — and every filter the app shows
/// is derived from these rows at read time. Changing a band threshold or a
/// synonym table re-labels the whole library retroactively, with no
/// re-collection, because nothing derived is ever written down.
///
/// It is also what makes extraction deterministic in practice: a review is
/// extracted once, keyed by its id, and the first answer is the answer. The
/// classifier's ±1 flapping on borderline sentences (measured 6/11 stable when
/// re-run from scratch) stops mattering when there is no second run.
export function createPlaceStore({ path = ":memory:" } = {}) {
  if (path !== ":memory:") {
    mkdirSync(dirname(path), { recursive: true });
  }
  const db = new DatabaseSync(path);
  db.exec(`
    PRAGMA journal_mode = WAL;
    CREATE TABLE IF NOT EXISTS places (
      fid TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      address TEXT,
      latitude REAL,
      longitude REAL,
      category TEXT,
      price_level TEXT,
      opening_hours TEXT,
      booking_links TEXT,
      fetched_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS evidence (
      fid TEXT NOT NULL,
      source TEXT NOT NULL,
      source_id TEXT NOT NULL,
      topic TEXT NOT NULL,
      quote TEXT NOT NULL,
      said_at TEXT,
      added_at INTEGER NOT NULL,
      PRIMARY KEY (fid, source, source_id, topic)
    );
    CREATE TABLE IF NOT EXISTS processed (
      fid TEXT NOT NULL,
      source TEXT NOT NULL,
      source_id TEXT NOT NULL,
      PRIMARY KEY (fid, source, source_id)
    );
    CREATE TABLE IF NOT EXISTS resolutions (
      name_norm TEXT NOT NULL,
      area_norm TEXT NOT NULL,
      fid TEXT NOT NULL,
      resolved_at INTEGER NOT NULL,
      PRIMARY KEY (name_norm, area_norm)
    );
  `);

  const upsertPlace = db.prepare(`
    INSERT INTO places (fid, name, address, latitude, longitude, category,
                        price_level, opening_hours, booking_links, fetched_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(fid) DO UPDATE SET
      name = excluded.name, address = excluded.address,
      latitude = excluded.latitude, longitude = excluded.longitude,
      category = excluded.category, price_level = excluded.price_level,
      opening_hours = excluded.opening_hours, booking_links = excluded.booking_links,
      fetched_at = excluded.fetched_at
  `);
  const selectPlace = db.prepare(`SELECT * FROM places WHERE fid = ?`);
  const insertEvidence = db.prepare(`
    INSERT OR IGNORE INTO evidence (fid, source, source_id, topic, quote, said_at, added_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);
  const selectEvidence = db.prepare(`
    SELECT source, source_id AS sourceId, topic, quote, said_at AS saidAt
    FROM evidence WHERE fid = ? ORDER BY added_at, rowid
  `);
  const markProcessed = db.prepare(`
    INSERT OR IGNORE INTO processed (fid, source, source_id) VALUES (?, ?, ?)
  `);
  const upsertResolution = db.prepare(`
    INSERT INTO resolutions (name_norm, area_norm, fid, resolved_at)
    VALUES (?, ?, ?, ?)
    ON CONFLICT(name_norm, area_norm) DO UPDATE SET
      fid = excluded.fid, resolved_at = excluded.resolved_at
  `);
  const selectResolution = db.prepare(`
    SELECT fid, resolved_at AS resolvedAt FROM resolutions
    WHERE name_norm = ? AND area_norm = ?
  `);
  const selectProcessed = db.prepare(`
    SELECT source_id AS sourceId FROM processed WHERE fid = ? AND source = ?
  `);

  return {
    savePlace(place, { now = Date.now() } = {}) {
      upsertPlace.run(
        place.fid,
        place.name,
        place.address ?? null,
        place.latitude ?? null,
        place.longitude ?? null,
        place.category ?? null,
        place.priceLevel ?? null,
        place.openingHours ? JSON.stringify(place.openingHours) : null,
        place.bookingLinks?.length ? JSON.stringify(place.bookingLinks) : null,
        now,
      );
    },

    getPlace(fid) {
      const row = selectPlace.get(fid);
      if (!row) return null;
      return {
        fid: row.fid,
        name: row.name,
        address: row.address,
        latitude: row.latitude,
        longitude: row.longitude,
        category: row.category,
        priceLevel: row.price_level,
        openingHours: row.opening_hours ? JSON.parse(row.opening_hours) : null,
        bookingLinks: row.booking_links ? JSON.parse(row.booking_links) : [],
        fetchedAt: row.fetched_at,
      };
    },

    /// Append-only on purpose: a topic once evidenced stays evidenced, and the
    /// same (source, id, topic) arriving again is a no-op rather than a rewrite.
    addEvidence(fid, items, { now = Date.now() } = {}) {
      for (const item of items) {
        insertEvidence.run(fid, item.source, item.sourceId, item.topic, item.quote, item.saidAt ?? null, now);
      }
    },

    evidenceFor(fid) {
      return selectEvidence.all(fid);
    },

    /// A review with nothing to say is still work done — recording that is what
    /// keeps the next visit from paying to extract it again.
    markProcessed(fid, source, sourceIds) {
      for (const sourceId of sourceIds) markProcessed.run(fid, source, sourceId);
    },

    processedIds(fid, source) {
      return new Set(selectProcessed.all(fid, source).map((row) => row.sourceId));
    },

    /// A (name, area) once resolved keeps its fid. This is what makes repeat
    /// lookups free of Serper entirely, and it freezes identity — a ranking
    /// shuffle upstream cannot quietly move an old capture to another shop.
    saveResolution(nameNorm, areaNorm, fid, { now = Date.now() } = {}) {
      upsertResolution.run(nameNorm, areaNorm, fid, now);
    },

    getResolution(nameNorm, areaNorm) {
      return selectResolution.get(nameNorm, areaNorm) ?? null;
    },

    close() {
      db.close();
    },
  };
}
