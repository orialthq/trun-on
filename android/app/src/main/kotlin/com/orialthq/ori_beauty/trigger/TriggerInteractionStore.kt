package com.orialthq.ori_beauty.trigger

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

enum class TriggerOutcomeKind {
    FIRED,
    DONE,
    LATER,
}

data class PendingTriggerOutcome(
    val eventId: String,
    val ruleId: String,
    val kind: TriggerOutcomeKind,
    val occurredAtMillis: Long,
    val snoozedUntilMillis: Long? = null,
    val eventKey: String? = null,
)

data class PendingTriggerOpen(
    val eventId: String,
    val ruleId: String,
    val destinationId: String,
    val occurredAtMillis: Long,
)

/** Process-death-safe handoff from notification/receiver code to Flutter. */
class TriggerInteractionStore(context: Context) {
    private val preferences =
        context.applicationContext.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    fun enqueueOutcome(
        ruleId: String,
        kind: TriggerOutcomeKind,
        occurredAtMillis: Long,
        snoozedUntilMillis: Long? = null,
        eventKey: String? = null,
    ): PendingTriggerOutcome? =
        synchronized(INTERACTION_LOCK) {
            if (ruleId.isBlank()) return@synchronized null
            val event =
                PendingTriggerOutcome(
                    eventId = UUID.randomUUID().toString(),
                    ruleId = ruleId,
                    kind = kind,
                    occurredAtMillis = occurredAtMillis,
                    snoozedUntilMillis = snoozedUntilMillis,
                    eventKey = eventKey,
                )
            val pending = (readOutcomes() + event).takeLast(MAX_PENDING_EVENTS)
            if (writeOutcomes(pending)) event else null
        }

    fun pendingOutcomes(): List<PendingTriggerOutcome> =
        synchronized(INTERACTION_LOCK) { readOutcomes() }

    fun acknowledgeOutcomes(eventIds: Collection<String>): Boolean =
        synchronized(INTERACTION_LOCK) {
            if (eventIds.isEmpty()) return@synchronized true
            val acknowledged = eventIds.toSet()
            writeOutcomes(readOutcomes().filterNot { it.eventId in acknowledged })
        }

    fun enqueueOpen(
        ruleId: String,
        destinationId: String,
        occurredAtMillis: Long,
    ): PendingTriggerOpen? =
        synchronized(INTERACTION_LOCK) {
            if (ruleId.isBlank() || destinationId.isBlank()) return@synchronized null
            val pending = readOpens()
            // Activity intent delivery can be repeated during task recreation. Keep one unresolved
            // destination per rule while still allowing it again after Flutter acknowledges it.
            val existing = pending.lastOrNull { it.ruleId == ruleId && it.destinationId == destinationId }
            if (existing != null) return@synchronized existing
            val event =
                PendingTriggerOpen(
                    eventId = UUID.randomUUID().toString(),
                    ruleId = ruleId,
                    destinationId = destinationId,
                    occurredAtMillis = occurredAtMillis,
                )
            val updated = (pending + event).takeLast(MAX_PENDING_EVENTS)
            if (writeOpens(updated)) event else null
        }

    fun pendingOpens(): List<PendingTriggerOpen> =
        synchronized(INTERACTION_LOCK) { readOpens() }

    fun acknowledgeOpens(eventIds: Collection<String>): Boolean =
        synchronized(INTERACTION_LOCK) {
            if (eventIds.isEmpty()) return@synchronized true
            val acknowledged = eventIds.toSet()
            writeOpens(readOpens().filterNot { it.eventId in acknowledged })
        }

    private fun readOutcomes(): List<PendingTriggerOutcome> =
        parseArray(preferences.getString(KEY_OUTCOMES, null)) { item ->
            PendingTriggerOutcome(
                eventId = item.getString("eventId"),
                ruleId = item.getString("ruleId"),
                kind = TriggerOutcomeKind.valueOf(item.getString("kind").uppercase()),
                occurredAtMillis = item.getLong("occurredAtMillis"),
                snoozedUntilMillis = item.nullableLong("snoozedUntilMillis"),
                eventKey = item.nullableString("eventKey"),
            )
        }

    private fun writeOutcomes(events: List<PendingTriggerOutcome>): Boolean =
        preferences
            .edit()
            .putString(
                KEY_OUTCOMES,
                JSONArray().apply {
                    events.forEach { event ->
                        put(
                            JSONObject()
                                .put("eventId", event.eventId)
                                .put("ruleId", event.ruleId)
                                .put("kind", event.kind.name.lowercase())
                                .put("occurredAtMillis", event.occurredAtMillis)
                                .put(
                                    "snoozedUntilMillis",
                                    event.snoozedUntilMillis ?: JSONObject.NULL,
                                )
                                .put("eventKey", event.eventKey ?: JSONObject.NULL),
                        )
                    }
                }.toString(),
            )
            .commit()

    private fun readOpens(): List<PendingTriggerOpen> =
        parseArray(preferences.getString(KEY_OPENS, null)) { item ->
            PendingTriggerOpen(
                eventId = item.getString("eventId"),
                ruleId = item.getString("ruleId"),
                destinationId = item.getString("destinationId"),
                occurredAtMillis = item.getLong("occurredAtMillis"),
            )
        }

    private fun writeOpens(events: List<PendingTriggerOpen>): Boolean =
        preferences
            .edit()
            .putString(
                KEY_OPENS,
                JSONArray().apply {
                    events.forEach { event ->
                        put(
                            JSONObject()
                                .put("eventId", event.eventId)
                                .put("ruleId", event.ruleId)
                                .put("destinationId", event.destinationId)
                                .put("occurredAtMillis", event.occurredAtMillis),
                        )
                    }
                }.toString(),
            )
            .commit()

    private fun <T> parseArray(
        raw: String?,
        decoder: (JSONObject) -> T,
    ): List<T> {
        if (raw == null) return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    runCatching { decoder(array.getJSONObject(index)) }.getOrNull()?.let(::add)
                }
            }
        }.getOrDefault(emptyList())
    }

    private fun JSONObject.nullableLong(key: String): Long? =
        if (!has(key) || isNull(key)) null else getLong(key)

    private fun JSONObject.nullableString(key: String): String? =
        if (!has(key) || isNull(key)) null else getString(key)

    companion object {
        private const val PREFERENCES_NAME = "place_reminders"
        private const val KEY_OUTCOMES = "trigger_pending_outcomes_v1"
        private const val KEY_OPENS = "trigger_pending_opens_v1"
        private const val MAX_PENDING_EVENTS = 100
        private val INTERACTION_LOCK = Any()
    }
}
