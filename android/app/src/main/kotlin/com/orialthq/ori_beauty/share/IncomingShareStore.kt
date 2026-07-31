package com.orialthq.ori_beauty.share

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

class IncomingShareStore(context: Context) {
    private val preferences =
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    @Synchronized
    fun append(payload: IncomingSharePayload) {
        val pending = readArray()
        val item =
            JSONObject()
                .put("id", payload.id)
                .put("receivedAtEpochMs", payload.receivedAtEpochMs)
                .put("sharedText", payload.sharedText)
                .put("discoveredUrl", payload.discoveredUrl)
                .put("sourcePackage", payload.sourcePackage)
                .put("mimeType", payload.mimeType)
                .put("wasTruncated", payload.wasTruncated)
                .put("originalLength", payload.originalLength)

        pending.put(item)
        writeArray(pending)
    }

    @Synchronized
    fun pending(): List<Map<String, Any?>> {
        val pending = readArray()
        return buildList {
            for (index in 0 until pending.length()) {
                val item = pending.getJSONObject(index)
                add(
                    mapOf(
                        "id" to item.getString("id"),
                        "receivedAtEpochMs" to item.getLong("receivedAtEpochMs"),
                        "sharedText" to item.getString("sharedText"),
                        "discoveredUrl" to item.optString("discoveredUrl").ifBlank { null },
                        "sourcePackage" to
                            item.optString("sourcePackage").ifBlank { null },
                        "mimeType" to item.optString("mimeType", "text/plain"),
                        "wasTruncated" to item.optBoolean("wasTruncated", false),
                        "originalLength" to
                            item.optInt(
                                "originalLength",
                                item.getString("sharedText").length,
                            ),
                    ),
                )
            }
        }
    }

    @Synchronized
    fun loadAppSnapshot(): String? = preferences.getString(KEY_APP_SNAPSHOT, null)

    @Synchronized
    fun saveAppSnapshot(snapshot: String): Boolean {
        if (snapshot.isBlank()) {
            return false
        }
        return preferences
            .edit()
            .putString(KEY_APP_SNAPSHOT, snapshot)
            .commit()
    }

    @Synchronized
    fun acknowledge(ids: Collection<String>) {
        if (ids.isEmpty()) {
            return
        }
        val pending = readArray()
        val remaining = JSONArray()
        for (index in 0 until pending.length()) {
            val item = pending.getJSONObject(index)
            if (item.getString("id") !in ids) {
                remaining.put(item)
            }
        }
        writeArray(remaining)
    }

    private fun readArray(): JSONArray {
        val raw = preferences.getString(KEY_PENDING_SHARES, null)
        return if (raw.isNullOrBlank()) JSONArray() else runCatching { JSONArray(raw) }
            .getOrDefault(JSONArray())
    }

    private fun writeArray(value: JSONArray) {
        preferences.edit().putString(KEY_PENDING_SHARES, value.toString()).apply()
    }

    companion object {
        private const val PREFERENCES_NAME = "incoming_share_store"
        private const val KEY_PENDING_SHARES = "pending_shares_v1"
        private const val KEY_APP_SNAPSHOT = "app_snapshot_v1"
    }
}
