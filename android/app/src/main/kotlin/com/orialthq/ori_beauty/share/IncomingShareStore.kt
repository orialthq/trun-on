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

        pending.put(item)
        val trimmed = JSONArray()
        val start = maxOf(0, pending.length() - MAX_PENDING_SHARES)
        for (index in start until pending.length()) {
            trimmed.put(pending.getJSONObject(index))
        }
        writeArray(trimmed)
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
                    ),
                )
            }
        }
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
        private const val MAX_PENDING_SHARES = 50
    }
}
