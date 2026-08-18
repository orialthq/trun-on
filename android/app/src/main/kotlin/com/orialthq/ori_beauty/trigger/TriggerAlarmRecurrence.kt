package com.orialthq.ori_beauty.trigger

import java.util.Calendar

/** Calendar-based recurrence preserves the user's local wall-clock across DST changes. */
object TriggerAlarmRecurrence {
    fun next(
        recurrence: TriggerRecurrence,
        scheduledAtMillis: Long,
        timeZoneId: String?,
    ): Long? {
        val calendar =
            Calendar.getInstance(TriggerTimeZones.resolve(timeZoneId)).apply {
                timeInMillis = scheduledAtMillis
            }
        when (recurrence) {
            TriggerRecurrence.DAILY -> calendar.add(Calendar.DAY_OF_YEAR, 1)
            TriggerRecurrence.WEEKLY -> calendar.add(Calendar.WEEK_OF_YEAR, 1)
            TriggerRecurrence.ONCE, TriggerRecurrence.ON_REENTRY -> return null
        }
        return calendar.timeInMillis
    }

    fun firstAtOrAfter(
        recurrence: TriggerRecurrence,
        firstFireAtMillis: Long,
        thresholdMillis: Long,
        timeZoneId: String?,
    ): Long? {
        if (recurrence == TriggerRecurrence.ONCE) return firstFireAtMillis
        var candidate = firstFireAtMillis
        while (candidate < thresholdMillis) {
            candidate = next(recurrence, candidate, timeZoneId) ?: return null
        }
        return candidate
    }
}
