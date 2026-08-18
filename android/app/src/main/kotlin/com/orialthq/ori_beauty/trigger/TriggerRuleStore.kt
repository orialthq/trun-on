package com.orialthq.ori_beauty.trigger

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

data class TriggerClaim(
    val rule: TriggerRule?,
    val event: TriggerEvent?,
    val decision: TriggerDecision,
)

/**
 * Persists generic trigger data alongside, but never over, the legacy place reminder keys.
 * Existing installs can therefore keep using reminders_v1 while the new scheduler is rolled out.
 */
class TriggerRuleStore(context: Context) {
    private val preferences: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    fun allRules(): List<TriggerRule> = synchronized(STORAGE_LOCK) { readRules() }

    fun findRule(id: String): TriggerRule? =
        synchronized(STORAGE_LOCK) { readRules().firstOrNull { it.id == id } }

    fun runtimeState(id: String): TriggerRuntimeState? =
        synchronized(STORAGE_LOCK) { readStates().firstOrNull { it.ruleId == id } }

    fun allRuntimeStates(): List<TriggerRuntimeState> =
        synchronized(STORAGE_LOCK) { readStates() }

    fun upsertRule(
        rule: TriggerRule,
        resetRuntimeState: Boolean = false,
    ): Boolean =
        synchronized(STORAGE_LOCK) {
            val rules = readRules().filterNot { it.id == rule.id } + rule
            val editor = preferences.edit().putString(KEY_RULES, TriggerJsonCodec.encodeRules(rules))
            if (resetRuntimeState) {
                editor.putString(
                    KEY_STATES,
                    TriggerJsonCodec.encodeStates(readStates().filterNot { it.ruleId == rule.id }),
                )
            }
            editor.commit()
        }

    fun removeRule(id: String): Boolean =
        synchronized(STORAGE_LOCK) {
            preferences
                .edit()
                .putString(
                    KEY_RULES,
                    TriggerJsonCodec.encodeRules(readRules().filterNot { it.id == id }),
                )
                .putString(
                    KEY_STATES,
                    TriggerJsonCodec.encodeStates(readStates().filterNot { it.ruleId == id }),
                )
                .commit()
        }

    /** Replaces only generic rules; legacy reminders_v1 is never read or changed here. */
    fun replaceRules(
        rules: List<TriggerRule>,
        resetRuntimeStateIds: Set<String> = emptySet(),
    ): Boolean =
        synchronized(STORAGE_LOCK) {
            require(rules.map(TriggerRule::id).distinct().size == rules.size) {
                "Trigger ids must be unique."
            }
            val retainedIds = rules.mapTo(mutableSetOf(), TriggerRule::id)
            val retainedStates =
                readStates().filter { state ->
                    state.ruleId in retainedIds && state.ruleId !in resetRuntimeStateIds
                }
            preferences
                .edit()
                .putString(KEY_RULES, TriggerJsonCodec.encodeRules(rules))
                .putString(KEY_STATES, TriggerJsonCodec.encodeStates(retainedStates))
                .commit()
        }

    fun resetRuntimeState(id: String): Boolean =
        synchronized(STORAGE_LOCK) {
            writeStates(readStates().filterNot { it.ruleId == id })
        }

    /** Atomically evaluates and records a geofence delivery, preventing receiver races. */
    fun claimGeofenceNotification(
        ruleId: String,
        occurredAtMillis: Long,
    ): TriggerClaim =
        synchronized(STORAGE_LOCK) {
            val rule = readRules().firstOrNull { it.id == ruleId }
                ?: return@synchronized TriggerClaim(
                    rule = null,
                    event = null,
                    decision = TriggerDecision.Suppress(TriggerSuppressionReason.RULE_NOT_FOUND),
                )
            val event = TriggerEvent.geofenceEntry(rule, occurredAtMillis)
            claim(rule, event, applyPolicy = true)
        }

    /** Claims the exact persisted snooze. Stale alarms cannot revive a newer or completed rule. */
    fun claimSnoozedNotification(
        ruleId: String,
        scheduledAtMillis: Long,
        occurredAtMillis: Long,
    ): TriggerClaim =
        synchronized(STORAGE_LOCK) {
            val rule = readRules().firstOrNull { it.id == ruleId }
                ?: return@synchronized TriggerClaim(
                    rule = null,
                    event = null,
                    decision = TriggerDecision.Suppress(TriggerSuppressionReason.RULE_NOT_FOUND),
                )
            val state = readStates().firstOrNull { it.ruleId == ruleId }
            val suppression =
                when {
                    !rule.enabled -> TriggerSuppressionReason.DISABLED
                    state?.completedAtMillis != null -> TriggerSuppressionReason.COMPLETED
                    state?.snoozedUntilMillis != scheduledAtMillis ->
                        TriggerSuppressionReason.STALE_SNOOZE
                    occurredAtMillis < scheduledAtMillis -> TriggerSuppressionReason.SNOOZED
                    else -> null
                }
            if (suppression != null) {
                return@synchronized TriggerClaim(
                    rule = rule,
                    event = null,
                    decision = TriggerDecision.Suppress(suppression),
                )
            }
            claim(
                rule = rule,
                event = TriggerEvent.snooze(ruleId, occurredAtMillis),
                applyPolicy = false,
            )
        }

    /** Claims only the currently armed wall-clock occurrence; replaced alarms are ignored. */
    fun claimScheduledNotification(
        ruleId: String,
        scheduledAtMillis: Long,
        occurredAtMillis: Long,
    ): TriggerClaim =
        synchronized(STORAGE_LOCK) {
            val rule = readRules().firstOrNull { it.id == ruleId }
                ?: return@synchronized TriggerClaim(
                    rule = null,
                    event = null,
                    decision = TriggerDecision.Suppress(TriggerSuppressionReason.RULE_NOT_FOUND),
                )
            val state = readStates().firstOrNull { it.ruleId == ruleId }
            if (rule.alarmSchedule == null || state?.nextAlarmAtMillis != scheduledAtMillis) {
                return@synchronized TriggerClaim(
                    rule = rule,
                    event = null,
                    decision = TriggerDecision.Suppress(TriggerSuppressionReason.STALE_ALARM),
                )
            }
            claim(
                rule = rule,
                event =
                    TriggerEvent.scheduledAlarm(
                        ruleId = ruleId,
                        scheduledAtMillis = scheduledAtMillis,
                        occurredAtMillis = occurredAtMillis,
                    ),
                applyPolicy = true,
            )
        }

    fun setNextAlarm(
        ruleId: String,
        nextAlarmAtMillis: Long?,
    ): Boolean =
        synchronized(STORAGE_LOCK) {
            if (readRules().none { it.id == ruleId }) return@synchronized false
            val states = readStates()
            val previous = states.firstOrNull { it.ruleId == ruleId }
            val updated =
                (previous ?: TriggerRuntimeState(ruleId = ruleId)).copy(
                    nextAlarmAtMillis = nextAlarmAtMillis,
                )
            writeStates(states.filterNot { it.ruleId == ruleId } + updated)
        }

    fun markCompleted(
        ruleId: String,
        completedAtMillis: Long,
    ): Boolean =
        synchronized(STORAGE_LOCK) {
            if (readRules().none { it.id == ruleId }) return@synchronized false
            val states = readStates()
            val previous = states.firstOrNull { it.ruleId == ruleId }
            val updated =
                (previous ?: TriggerRuntimeState(ruleId = ruleId)).copy(
                    completedAtMillis = completedAtMillis,
                    snoozedUntilMillis = null,
                    nextAlarmAtMillis = null,
                )
            writeStates(states.filterNot { it.ruleId == ruleId } + updated)
        }

    fun markSnoozed(
        ruleId: String,
        snoozedUntilMillis: Long,
    ): Boolean =
        synchronized(STORAGE_LOCK) {
            if (readRules().none { it.id == ruleId }) return@synchronized false
            val states = readStates()
            val previous = states.firstOrNull { it.ruleId == ruleId }
            if (previous?.completedAtMillis != null) return@synchronized false
            val updated =
                (previous ?: TriggerRuntimeState(ruleId = ruleId)).copy(
                    snoozedUntilMillis = snoozedUntilMillis,
                )
            writeStates(states.filterNot { it.ruleId == ruleId } + updated)
        }

    private fun claim(
        rule: TriggerRule,
        event: TriggerEvent,
        applyPolicy: Boolean,
    ): TriggerClaim {
        val states = readStates()
        val previous = states.firstOrNull { it.ruleId == rule.id }
        val decision =
            if (applyPolicy) {
                TriggerRuleEvaluator.evaluate(rule, previous, event)
            } else {
                TriggerDecision.Notify
            }
        if (decision != TriggerDecision.Notify) {
            return TriggerClaim(rule = rule, event = event, decision = decision)
        }
        val updated = TriggerRuleEvaluator.stateAfterNotification(rule, previous, event)
        val committed = writeStates(states.filterNot { it.ruleId == rule.id } + updated)
        return TriggerClaim(
            rule = rule,
            event = event,
            decision =
                if (committed) {
                    TriggerDecision.Notify
                } else {
                    TriggerDecision.Suppress(TriggerSuppressionReason.STORAGE_FAILURE)
                },
        )
    }

    private fun readRules(): List<TriggerRule> =
        preferences.getString(KEY_RULES, null)?.let(TriggerJsonCodec::decodeRules).orEmpty()

    private fun readStates(): List<TriggerRuntimeState> =
        preferences.getString(KEY_STATES, null)?.let(TriggerJsonCodec::decodeStates).orEmpty()

    private fun writeStates(states: List<TriggerRuntimeState>): Boolean =
        preferences.edit().putString(KEY_STATES, TriggerJsonCodec.encodeStates(states)).commit()

    companion object {
        // Deliberately shared with PlaceReminderStore. Its reminders_v1 and pending_opens_v1
        // remain untouched and readable by all released app versions.
        private const val PREFERENCES_NAME = "place_reminders"
        private const val KEY_RULES = "trigger_rules_v1"
        private const val KEY_STATES = "trigger_runtime_states_v1"
        private val STORAGE_LOCK = Any()
    }
}

private object TriggerJsonCodec {
    private const val SCHEMA_VERSION = 1

    fun encodeRules(rules: List<TriggerRule>): String =
        envelope(
            JSONArray().apply {
                rules.forEach { rule -> put(rule.toJson()) }
            },
        ).toString()

    fun decodeRules(raw: String): List<TriggerRule> =
        decodeItems(raw) { item -> item.toTriggerRule() }

    fun encodeStates(states: List<TriggerRuntimeState>): String =
        envelope(
            JSONArray().apply {
                states.forEach { state -> put(state.toJson()) }
            },
        ).toString()

    fun decodeStates(raw: String): List<TriggerRuntimeState> =
        decodeItems(raw) { item -> item.toRuntimeState() }

    private fun envelope(items: JSONArray): JSONObject =
        JSONObject()
            .put("schemaVersion", SCHEMA_VERSION)
            .put("items", items)

    /** Accepts both the current envelope and an early bare-array representation. */
    private fun <T> decodeItems(
        raw: String,
        decoder: (JSONObject) -> T,
    ): List<T> =
        runCatching {
            val trimmed = raw.trim()
            val items =
                if (trimmed.startsWith("[")) {
                    JSONArray(trimmed)
                } else {
                    JSONObject(trimmed).optJSONArray("items") ?: JSONArray()
                }
            buildList {
                for (index in 0 until items.length()) {
                    val decoded = runCatching { decoder(items.getJSONObject(index)) }.getOrNull()
                    if (decoded != null) add(decoded)
                }
            }
        }.getOrDefault(emptyList())

    private fun TriggerRule.toJson(): JSONObject =
        JSONObject()
            .put("id", id)
            .put("destinationId", destinationId)
            .put("title", title)
            .put("message", message)
            .put("location", location?.toJson() ?: JSONObject.NULL)
            .put("alarmSchedule", alarmSchedule?.toJson() ?: JSONObject.NULL)
            .put("enabled", enabled)
            .put("activeFromMillis", activeFromMillis ?: JSONObject.NULL)
            .put("activeUntilMillis", activeUntilMillis ?: JSONObject.NULL)
            .put("timeWindow", timeWindow?.toJson() ?: JSONObject.NULL)
            .put("cooldownMillis", cooldownMillis)
            .put("dedupeWindowMillis", dedupeWindowMillis)
            .put("recurrence", recurrence.name.lowercase())
            .put("laterDelayMillis", laterDelayMillis)
            .put("createdAtMillis", createdAtMillis)
            .put("updatedAtMillis", updatedAtMillis)

    private fun JSONObject.toTriggerRule(): TriggerRule {
        val id = getString("id").trim()
        val location =
            optJSONObject("location")?.toLocation()
                ?: if (has("latitude") && !isNull("latitude")) {
                    TriggerLocation(
                        latitude = getDouble("latitude"),
                        longitude = getDouble("longitude"),
                        radiusMeters = getDouble("radiusMeters").toFloat(),
                    )
                } else {
                    null
                }
        val alarmSchedule = optJSONObject("alarmSchedule")?.toAlarmSchedule()
        return TriggerRule(
            id = id,
            destinationId = nullableString("destinationId") ?: nullableString("captureId") ?: id,
            title = getString("title").trim(),
            message = optString("message", "저장해 둔 내용을 확인해 봐."),
            location = location,
            alarmSchedule = alarmSchedule,
            enabled = if (has("enabled")) getBoolean("enabled") else true,
            activeFromMillis = nullableLong("activeFromMillis"),
            activeUntilMillis = nullableLong("activeUntilMillis"),
            timeWindow = optJSONObject("timeWindow")?.toTimeWindow(),
            cooldownMillis = optLong("cooldownMillis", TriggerRule.DEFAULT_COOLDOWN_MILLIS),
            dedupeWindowMillis =
                optLong("dedupeWindowMillis", TriggerRule.DEFAULT_DEDUPE_WINDOW_MILLIS),
            recurrence = decodeRecurrence(location, alarmSchedule),
            laterDelayMillis =
                optLong("laterDelayMillis", TriggerRule.DEFAULT_LATER_DELAY_MILLIS),
            createdAtMillis = optLong("createdAtMillis", 0),
            updatedAtMillis = optLong("updatedAtMillis", 0),
        )
    }

    private fun TriggerLocation.toJson(): JSONObject =
        JSONObject()
            .put("latitude", latitude)
            .put("longitude", longitude)
            .put("radiusMeters", radiusMeters.toDouble())

    private fun JSONObject.toLocation(): TriggerLocation =
        TriggerLocation(
            latitude = getDouble("latitude"),
            longitude = getDouble("longitude"),
            radiusMeters = getDouble("radiusMeters").toFloat(),
        )

    private fun TriggerAlarmSchedule.toJson(): JSONObject =
        JSONObject()
            .put("firstFireAtMillis", firstFireAtMillis)
            .put("timeZoneId", timeZoneId ?: JSONObject.NULL)

    private fun JSONObject.toAlarmSchedule(): TriggerAlarmSchedule =
        TriggerAlarmSchedule(
            firstFireAtMillis = getLong("firstFireAtMillis"),
            timeZoneId = nullableString("timeZoneId"),
        )

    private fun JSONObject.decodeRecurrence(
        location: TriggerLocation?,
        alarmSchedule: TriggerAlarmSchedule?,
    ): TriggerRecurrence {
        val raw = nullableString("recurrence") ?: nullableString("repeatPolicy")
        return when (raw?.lowercase()) {
            null -> if (alarmSchedule != null) TriggerRecurrence.ONCE else TriggerRecurrence.ON_REENTRY
            "once" -> TriggerRecurrence.ONCE
            "daily" -> TriggerRecurrence.DAILY
            "weekly" -> TriggerRecurrence.WEEKLY
            "on_reentry", "onreentry", "recurring" -> TriggerRecurrence.ON_REENTRY
            else -> throw IllegalArgumentException("Unknown recurrence: $raw")
        }.also { recurrence ->
            require(recurrence != TriggerRecurrence.ON_REENTRY || location != null)
        }
    }

    private fun TriggerTimeWindow.toJson(): JSONObject =
        JSONObject()
            .put("daysOfWeek", JSONArray().apply { daysOfWeek.sorted().forEach(::put) })
            .put("startMinuteOfDay", startMinuteOfDay)
            .put("endMinuteOfDay", endMinuteOfDay)
            .put("timeZoneId", timeZoneId ?: JSONObject.NULL)

    private fun JSONObject.toTimeWindow(): TriggerTimeWindow {
        val days =
            optJSONArray("daysOfWeek")?.let { array ->
                buildSet {
                    for (index in 0 until array.length()) add(array.getInt(index))
                }
            }.orEmpty().ifEmpty { TriggerTimeWindow.ALL_DAYS }
        return TriggerTimeWindow(
            daysOfWeek = days,
            startMinuteOfDay = getInt("startMinuteOfDay"),
            endMinuteOfDay = getInt("endMinuteOfDay"),
            timeZoneId = nullableString("timeZoneId"),
        )
    }

    private fun TriggerRuntimeState.toJson(): JSONObject =
        JSONObject()
            .put("ruleId", ruleId)
            .put("lastEventKey", lastEventKey ?: JSONObject.NULL)
            .put("lastEventAtMillis", lastEventAtMillis ?: JSONObject.NULL)
            .put("lastNotifiedAtMillis", lastNotifiedAtMillis ?: JSONObject.NULL)
            .put("firstNotifiedAtMillis", firstNotifiedAtMillis ?: JSONObject.NULL)
            .put("completedAtMillis", completedAtMillis ?: JSONObject.NULL)
            .put("snoozedUntilMillis", snoozedUntilMillis ?: JSONObject.NULL)
            .put("nextAlarmAtMillis", nextAlarmAtMillis ?: JSONObject.NULL)
            .put("notificationCount", notificationCount)

    private fun JSONObject.toRuntimeState(): TriggerRuntimeState =
        TriggerRuntimeState(
            ruleId = getString("ruleId"),
            lastEventKey = nullableString("lastEventKey"),
            lastEventAtMillis = nullableLong("lastEventAtMillis"),
            lastNotifiedAtMillis = nullableLong("lastNotifiedAtMillis"),
            firstNotifiedAtMillis = nullableLong("firstNotifiedAtMillis"),
            completedAtMillis = nullableLong("completedAtMillis"),
            snoozedUntilMillis = nullableLong("snoozedUntilMillis"),
            nextAlarmAtMillis = nullableLong("nextAlarmAtMillis"),
            notificationCount = optInt("notificationCount", 0),
        )

    private fun JSONObject.nullableString(key: String): String? =
        if (!has(key) || isNull(key)) null else getString(key).trim().takeIf(String::isNotEmpty)

    private fun JSONObject.nullableLong(key: String): Long? =
        if (!has(key) || isNull(key)) null else getLong(key)
}
