package com.orialthq.ori_beauty

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class StoredPlaceReminder(
    val id: String,
    val title: String,
    val address: String,
    val latitude: Double,
    val longitude: Double,
    val radiusMeters: Float,
)

class PlaceReminderStore(context: Context) {
    private val preferences =
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    @Synchronized
    fun all(): List<StoredPlaceReminder> {
        val raw = preferences.getString(KEY_REMINDERS, null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.getJSONObject(index)
                    add(
                        StoredPlaceReminder(
                            id = item.getString("id"),
                            title = item.getString("title"),
                            address = item.getString("address"),
                            latitude = item.getDouble("latitude"),
                            longitude = item.getDouble("longitude"),
                            radiusMeters = item.getDouble("radiusMeters").toFloat(),
                        ),
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    @Synchronized
    fun find(id: String): StoredPlaceReminder? = all().firstOrNull { it.id == id }

    @Synchronized
    fun upsert(reminder: StoredPlaceReminder): Boolean {
        val reminders = all().filterNot { it.id == reminder.id } + reminder
        return write(reminders)
    }

    @Synchronized
    fun remove(id: String): Boolean = write(all().filterNot { it.id == id })

    /** Keeps notification destinations across process death until Flutter routes them. */
    @Synchronized
    fun enqueuePendingOpen(id: String): Boolean {
        if (id.isBlank()) return false
        val pending = pendingOpenIds().filterNot { it == id } + id
        return writePendingOpenIds(pending)
    }

    @Synchronized
    fun pendingOpenIds(): List<String> {
        val raw = preferences.getString(KEY_PENDING_OPENS, null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    val id = array.optString(index).trim()
                    if (id.isNotEmpty() && id !in this) add(id)
                }
            }
        }.getOrDefault(emptyList())
    }

    @Synchronized
    fun acknowledgePendingOpens(ids: List<String>): Boolean {
        if (ids.isEmpty()) return true
        val acknowledged = ids.toSet()
        return writePendingOpenIds(pendingOpenIds().filterNot(acknowledged::contains))
    }

    private fun write(reminders: List<StoredPlaceReminder>): Boolean {
        val array =
            JSONArray().apply {
                reminders.forEach { reminder ->
                    put(
                        JSONObject()
                            .put("id", reminder.id)
                            .put("title", reminder.title)
                            .put("address", reminder.address)
                            .put("latitude", reminder.latitude)
                            .put("longitude", reminder.longitude)
                            .put("radiusMeters", reminder.radiusMeters.toDouble()),
                    )
                }
            }
        return preferences.edit().putString(KEY_REMINDERS, array.toString()).commit()
    }

    private fun writePendingOpenIds(ids: List<String>): Boolean {
        val array = JSONArray().apply { ids.forEach(::put) }
        return preferences.edit().putString(KEY_PENDING_OPENS, array.toString()).commit()
    }

    companion object {
        private const val PREFERENCES_NAME = "place_reminders"
        private const val KEY_REMINDERS = "reminders_v1"
        private const val KEY_PENDING_OPENS = "pending_opens_v1"
    }
}
