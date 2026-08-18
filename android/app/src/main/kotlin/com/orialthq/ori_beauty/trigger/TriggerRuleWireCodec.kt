package com.orialthq.ori_beauty.trigger

internal object TriggerRuleWireCodec {
    fun decodeRule(
        value: Any?,
        nowMillis: Long = System.currentTimeMillis(),
    ): TriggerRule {
        val map = value as? Map<*, *> ?: throw IllegalArgumentException("rule must be a map")
        val id = map.requiredString("id")
        val createdAt = map.optionalLong("createdAtMillis") ?: nowMillis
        val timeWindowMap = map["timeWindow"] as? Map<*, *>
        val location = map.decodeLocation()
        val alarmSchedule = (map["alarmSchedule"] as? Map<*, *>)?.decodeAlarmSchedule()
        val recurrence = map.decodeRecurrence(location, alarmSchedule)
        return TriggerRule(
            id = id,
            destinationId = map.optionalString("destinationId") ?: id,
            title = map.requiredString("title"),
            message = map.optionalString("message") ?: "저장해 둔 내용을 확인해 봐.",
            location = location,
            alarmSchedule = alarmSchedule,
            enabled = map["enabled"] as? Boolean ?: true,
            activeFromMillis = map.optionalLong("activeFromMillis"),
            activeUntilMillis = map.optionalLong("activeUntilMillis"),
            timeWindow = timeWindowMap?.decodeTimeWindow(),
            cooldownMillis =
                map.optionalLong("cooldownMillis") ?: TriggerRule.DEFAULT_COOLDOWN_MILLIS,
            dedupeWindowMillis =
                map.optionalLong("dedupeWindowMillis") ?: TriggerRule.DEFAULT_DEDUPE_WINDOW_MILLIS,
            recurrence = recurrence,
            laterDelayMillis =
                map.optionalLong("laterDelayMillis") ?: TriggerRule.DEFAULT_LATER_DELAY_MILLIS,
            createdAtMillis = createdAt,
            updatedAtMillis = map.optionalLong("updatedAtMillis") ?: nowMillis,
        )
    }

    fun encodeRule(rule: TriggerRule): Map<String, Any?> =
        mapOf(
            "id" to rule.id,
            "destinationId" to rule.destinationId,
            "title" to rule.title,
            "message" to rule.message,
            "location" to rule.location?.let(::encodeLocation),
            "alarmSchedule" to rule.alarmSchedule?.let(::encodeAlarmSchedule),
            "enabled" to rule.enabled,
            "activeFromMillis" to rule.activeFromMillis,
            "activeUntilMillis" to rule.activeUntilMillis,
            "timeWindow" to rule.timeWindow?.let(::encodeTimeWindow),
            "cooldownMillis" to rule.cooldownMillis,
            "dedupeWindowMillis" to rule.dedupeWindowMillis,
            "recurrence" to rule.recurrence.name.lowercase(),
            "laterDelayMillis" to rule.laterDelayMillis,
            "createdAtMillis" to rule.createdAtMillis,
            "updatedAtMillis" to rule.updatedAtMillis,
        )

    fun encodeState(state: TriggerRuntimeState?): Map<String, Any?>? =
        state?.let {
            mapOf(
                "ruleId" to it.ruleId,
                "lastEventKey" to it.lastEventKey,
                "lastEventAtMillis" to it.lastEventAtMillis,
                "lastNotifiedAtMillis" to it.lastNotifiedAtMillis,
                "firstNotifiedAtMillis" to it.firstNotifiedAtMillis,
                "completedAtMillis" to it.completedAtMillis,
                "snoozedUntilMillis" to it.snoozedUntilMillis,
                "nextAlarmAtMillis" to it.nextAlarmAtMillis,
                "notificationCount" to it.notificationCount,
            )
        }

    fun encodeOutcome(event: PendingTriggerOutcome): Map<String, Any?> =
        mapOf(
            "eventId" to event.eventId,
            "ruleId" to event.ruleId,
            "kind" to event.kind.name.lowercase(),
            "occurredAtMillis" to event.occurredAtMillis,
            "snoozedUntilMillis" to event.snoozedUntilMillis,
            "eventKey" to event.eventKey,
        )

    fun encodeOpen(event: PendingTriggerOpen): Map<String, Any> =
        mapOf(
            "eventId" to event.eventId,
            "ruleId" to event.ruleId,
            "destinationId" to event.destinationId,
            "occurredAtMillis" to event.occurredAtMillis,
        )

    private fun Map<*, *>.decodeTimeWindow(): TriggerTimeWindow {
        val days =
            (this["daysOfWeek"] as? List<*>)
                ?.map { value ->
                    (value as? Number)?.toInt()
                        ?: throw IllegalArgumentException("daysOfWeek values must be integers")
                }
                ?.toSet()
                ?: TriggerTimeWindow.ALL_DAYS
        return TriggerTimeWindow(
            daysOfWeek = days,
            startMinuteOfDay = requiredNumber("startMinuteOfDay").toInt(),
            endMinuteOfDay = requiredNumber("endMinuteOfDay").toInt(),
            timeZoneId = optionalString("timeZoneId"),
        )
    }

    private fun Map<*, *>.decodeLocation(): TriggerLocation? {
        val nested = this["location"] as? Map<*, *>
        val source = nested ?: this
        if (nested == null && this["latitude"] == null) return null
        return TriggerLocation(
            latitude = source.requiredNumber("latitude").toDouble(),
            longitude = source.requiredNumber("longitude").toDouble(),
            radiusMeters = source.requiredNumber("radiusMeters").toFloat(),
        )
    }

    private fun Map<*, *>.decodeAlarmSchedule(): TriggerAlarmSchedule =
        TriggerAlarmSchedule(
            firstFireAtMillis = requiredNumber("firstFireAtMillis").toLong(),
            timeZoneId = optionalString("timeZoneId"),
        )

    private fun Map<*, *>.decodeRecurrence(
        location: TriggerLocation?,
        alarmSchedule: TriggerAlarmSchedule?,
    ): TriggerRecurrence {
        val value = optionalString("recurrence")?.lowercase()
            ?: optionalString("repeatPolicy")?.lowercase()
        return when (value) {
            null -> if (alarmSchedule != null) TriggerRecurrence.ONCE else TriggerRecurrence.ON_REENTRY
            "once" -> TriggerRecurrence.ONCE
            "daily" -> TriggerRecurrence.DAILY
            "weekly" -> TriggerRecurrence.WEEKLY
            "on_reentry", "onreentry", "recurring" -> TriggerRecurrence.ON_REENTRY
            else -> throw IllegalArgumentException(
                "recurrence must be once, daily, weekly, or on_reentry",
            )
        }.also { recurrence ->
            if (recurrence == TriggerRecurrence.ON_REENTRY && location == null) {
                throw IllegalArgumentException("on_reentry recurrence requires location")
            }
        }
    }

    private fun encodeLocation(location: TriggerLocation): Map<String, Any> =
        mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "radiusMeters" to location.radiusMeters.toDouble(),
        )

    private fun encodeAlarmSchedule(schedule: TriggerAlarmSchedule): Map<String, Any?> =
        mapOf(
            "firstFireAtMillis" to schedule.firstFireAtMillis,
            "timeZoneId" to schedule.timeZoneId,
        )

    private fun encodeTimeWindow(window: TriggerTimeWindow): Map<String, Any?> =
        mapOf(
            "daysOfWeek" to window.daysOfWeek.sorted(),
            "startMinuteOfDay" to window.startMinuteOfDay,
            "endMinuteOfDay" to window.endMinuteOfDay,
            "timeZoneId" to window.timeZoneId,
        )

    private fun Map<*, *>.requiredString(key: String): String =
        optionalString(key) ?: throw IllegalArgumentException("$key is required")

    private fun Map<*, *>.optionalString(key: String): String? =
        (this[key] as? String)?.trim()?.takeIf(String::isNotEmpty)

    private fun Map<*, *>.requiredNumber(key: String): Number =
        this[key] as? Number ?: throw IllegalArgumentException("$key is required")

    private fun Map<*, *>.optionalLong(key: String): Long? =
        (this[key] as? Number)?.toLong()
}
