package com.orialthq.ori_beauty.trigger

/** A persisted native rule backed by either a geofence or an inexact wall-clock alarm. */
data class TriggerRule(
    val id: String,
    val destinationId: String,
    val title: String,
    val message: String,
    val location: TriggerLocation? = null,
    val alarmSchedule: TriggerAlarmSchedule? = null,
    val enabled: Boolean = true,
    val activeFromMillis: Long? = null,
    val activeUntilMillis: Long? = null,
    val timeWindow: TriggerTimeWindow? = null,
    val cooldownMillis: Long = DEFAULT_COOLDOWN_MILLIS,
    val dedupeWindowMillis: Long = DEFAULT_DEDUPE_WINDOW_MILLIS,
    val recurrence: TriggerRecurrence = TriggerRecurrence.ON_REENTRY,
    val laterDelayMillis: Long = DEFAULT_LATER_DELAY_MILLIS,
    val createdAtMillis: Long,
    val updatedAtMillis: Long,
) {
    init {
        require(id.isNotBlank()) { "Trigger id must not be blank." }
        require(destinationId.isNotBlank()) { "Destination id must not be blank." }
        require(title.isNotBlank()) { "Notification title must not be blank." }
        require(location != null || alarmSchedule != null) {
            "A trigger requires a location or an alarm schedule."
        }
        require(location == null || alarmSchedule == null) {
            "A rule cannot register both an alarm and a geofence; use a location time window for AND."
        }
        require(activeFromMillis == null || activeFromMillis >= 0) {
            "Active-from must not be negative."
        }
        require(activeUntilMillis == null || activeUntilMillis >= 0) {
            "Active-until must not be negative."
        }
        require(
            activeFromMillis == null ||
                activeUntilMillis == null ||
                activeUntilMillis >= activeFromMillis
        ) { "Active-until must not precede active-from." }
        require(recurrence != TriggerRecurrence.ON_REENTRY || location != null) {
            "on_reentry recurrence requires a location."
        }
        require(cooldownMillis >= 0) { "Cooldown must not be negative." }
        require(dedupeWindowMillis > 0) { "Dedupe window must be positive." }
        require(laterDelayMillis > 0) { "Later delay must be positive." }
        require(createdAtMillis >= 0 && updatedAtMillis >= 0) {
            "Timestamps must not be negative."
        }
    }

    companion object {
        const val DEFAULT_COOLDOWN_MILLIS = 6 * 60 * 60 * 1_000L
        const val DEFAULT_DEDUPE_WINDOW_MILLIS = 60 * 1_000L
        const val DEFAULT_LATER_DELAY_MILLIS = 30 * 60 * 1_000L
    }
}

data class TriggerLocation(
    val latitude: Double,
    val longitude: Double,
    val radiusMeters: Float,
) {
    init {
        require(latitude.isFinite() && latitude in -90.0..90.0) {
            "Latitude must be between -90 and 90."
        }
        require(longitude.isFinite() && longitude in -180.0..180.0) {
            "Longitude must be between -180 and 180."
        }
        require(radiusMeters.isFinite() && radiusMeters in MIN_RADIUS_METERS..MAX_RADIUS_METERS) {
            "Radius must be between $MIN_RADIUS_METERS and $MAX_RADIUS_METERS metres."
        }
    }

    companion object {
        const val MIN_RADIUS_METERS = 50f
        const val MAX_RADIUS_METERS = 10_000f
    }
}

data class TriggerAlarmSchedule(
    val firstFireAtMillis: Long,
    val timeZoneId: String? = null,
) {
    init {
        require(firstFireAtMillis >= 0) { "First alarm time must not be negative." }
        require(timeZoneId == null || timeZoneId.isNotBlank()) {
            "Time zone id must either be null or non-blank."
        }
        TriggerTimeZones.requireKnown(timeZoneId)
    }
}

enum class TriggerRecurrence {
    ONCE,
    DAILY,
    WEEKLY,
    ON_REENTRY,
}

/**
 * Local-time filter for a location rule. ISO weekday values are used (Monday=1 ... Sunday=7),
 * matching Dart's DateTime.weekday contract.
 *
 * A start later than the end represents an overnight window. For example, Monday 22:00-02:00
 * also matches Tuesday at 01:00. Equal start/end values represent the full selected day.
 */
data class TriggerTimeWindow(
    val daysOfWeek: Set<Int> = ALL_DAYS,
    val startMinuteOfDay: Int,
    val endMinuteOfDay: Int,
    val timeZoneId: String? = null,
) {
    init {
        require(daysOfWeek.isNotEmpty() && daysOfWeek.all { it in MONDAY..SUNDAY }) {
            "At least one valid day of week is required."
        }
        require(startMinuteOfDay in 0 until MINUTES_PER_DAY) {
            "Start minute must be within a day."
        }
        require(endMinuteOfDay in 0 until MINUTES_PER_DAY) {
            "End minute must be within a day."
        }
        require(timeZoneId == null || timeZoneId.isNotBlank()) {
            "Time zone id must either be null or non-blank."
        }
        TriggerTimeZones.requireKnown(timeZoneId)
    }

    companion object {
        const val MINUTES_PER_DAY = 24 * 60
        const val MONDAY = 1
        const val TUESDAY = 2
        const val WEDNESDAY = 3
        const val THURSDAY = 4
        const val FRIDAY = 5
        const val SATURDAY = 6
        const val SUNDAY = 7
        val ALL_DAYS: Set<Int> = (MONDAY..SUNDAY).toSet()
    }
}

/** Durable state is deliberately separate from the editable rule. */
data class TriggerRuntimeState(
    val ruleId: String,
    val lastEventKey: String? = null,
    val lastEventAtMillis: Long? = null,
    val lastNotifiedAtMillis: Long? = null,
    val firstNotifiedAtMillis: Long? = null,
    val completedAtMillis: Long? = null,
    val snoozedUntilMillis: Long? = null,
    val nextAlarmAtMillis: Long? = null,
    val notificationCount: Int = 0,
) {
    init {
        require(ruleId.isNotBlank()) { "Runtime state requires a rule id." }
        require(notificationCount >= 0) { "Notification count must not be negative." }
    }
}

data class TriggerEvent(
    val occurredAtMillis: Long,
    val eventKey: String,
) {
    init {
        require(occurredAtMillis >= 0) { "Event time must not be negative." }
        require(eventKey.isNotBlank()) { "Event key must not be blank." }
    }

    companion object {
        fun geofenceEntry(rule: TriggerRule, occurredAtMillis: Long): TriggerEvent {
            val bucket = occurredAtMillis / rule.dedupeWindowMillis
            return TriggerEvent(
                occurredAtMillis = occurredAtMillis,
                eventKey = "geofence-enter:$bucket",
            )
        }

        fun snooze(ruleId: String, dueAtMillis: Long): TriggerEvent =
            TriggerEvent(
                occurredAtMillis = dueAtMillis,
                eventKey = "snooze:$ruleId:$dueAtMillis",
            )

        fun scheduledAlarm(
            ruleId: String,
            scheduledAtMillis: Long,
            occurredAtMillis: Long = scheduledAtMillis,
        ): TriggerEvent =
            TriggerEvent(
                occurredAtMillis = occurredAtMillis,
                eventKey = "time:$ruleId:$scheduledAtMillis",
            )
    }
}
