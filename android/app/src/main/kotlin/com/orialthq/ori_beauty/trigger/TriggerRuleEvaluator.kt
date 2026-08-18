package com.orialthq.ori_beauty.trigger

import java.util.Calendar
import java.util.TimeZone

enum class TriggerSuppressionReason {
    RULE_NOT_FOUND,
    NOTIFICATION_PERMISSION_REQUIRED,
    DISABLED,
    COMPLETED,
    ONCE_ALREADY_FIRED,
    DAILY_ALREADY_FIRED,
    WEEKLY_ALREADY_FIRED,
    SNOOZED,
    BEFORE_ACTIVE_PERIOD,
    AFTER_ACTIVE_PERIOD,
    OUTSIDE_TIME_WINDOW,
    DUPLICATE_EVENT,
    COOLDOWN,
    STORAGE_FAILURE,
    STALE_SNOOZE,
    STALE_ALARM,
}

sealed class TriggerDecision {
    data object Notify : TriggerDecision()

    data class Suppress(val reason: TriggerSuppressionReason) : TriggerDecision()
}

/** Pure trigger policy. Keeping this Android-free makes all boundary behavior JVM-testable. */
object TriggerRuleEvaluator {
    fun evaluate(
        rule: TriggerRule,
        state: TriggerRuntimeState?,
        event: TriggerEvent,
    ): TriggerDecision {
        if (!rule.enabled) return TriggerDecision.Suppress(TriggerSuppressionReason.DISABLED)
        if (state?.completedAtMillis != null) {
            return TriggerDecision.Suppress(TriggerSuppressionReason.COMPLETED)
        }
        if (
            rule.recurrence == TriggerRecurrence.ONCE &&
                state?.firstNotifiedAtMillis != null
        ) {
            return TriggerDecision.Suppress(TriggerSuppressionReason.ONCE_ALREADY_FIRED)
        }
        if ((state?.snoozedUntilMillis ?: Long.MIN_VALUE) > event.occurredAtMillis) {
            return TriggerDecision.Suppress(TriggerSuppressionReason.SNOOZED)
        }
        if ((rule.activeFromMillis ?: Long.MIN_VALUE) > event.occurredAtMillis) {
            return TriggerDecision.Suppress(TriggerSuppressionReason.BEFORE_ACTIVE_PERIOD)
        }
        if ((rule.activeUntilMillis ?: Long.MAX_VALUE) <= event.occurredAtMillis) {
            return TriggerDecision.Suppress(TriggerSuppressionReason.AFTER_ACTIVE_PERIOD)
        }
        if (rule.timeWindow?.matches(event.occurredAtMillis) == false) {
            return TriggerDecision.Suppress(TriggerSuppressionReason.OUTSIDE_TIME_WINDOW)
        }
        if (state?.lastEventKey == event.eventKey) {
            return TriggerDecision.Suppress(TriggerSuppressionReason.DUPLICATE_EVENT)
        }
        val lastNotifiedAt = state?.lastNotifiedAtMillis
        if (
            lastNotifiedAt != null &&
                rule.recurrence == TriggerRecurrence.DAILY &&
                sameLocalDay(rule, lastNotifiedAt, event.occurredAtMillis)
        ) {
            return TriggerDecision.Suppress(TriggerSuppressionReason.DAILY_ALREADY_FIRED)
        }
        if (
            lastNotifiedAt != null &&
                rule.recurrence == TriggerRecurrence.WEEKLY &&
                sameLocalWeek(rule, lastNotifiedAt, event.occurredAtMillis)
        ) {
            return TriggerDecision.Suppress(TriggerSuppressionReason.WEEKLY_ALREADY_FIRED)
        }
        if (
            lastNotifiedAt != null &&
                event.occurredAtMillis < saturatedAdd(lastNotifiedAt, rule.cooldownMillis)
        ) {
            return TriggerDecision.Suppress(TriggerSuppressionReason.COOLDOWN)
        }
        return TriggerDecision.Notify
    }

    fun stateAfterNotification(
        rule: TriggerRule,
        previous: TriggerRuntimeState?,
        event: TriggerEvent,
    ): TriggerRuntimeState =
        TriggerRuntimeState(
            ruleId = rule.id,
            lastEventKey = event.eventKey,
            lastEventAtMillis = event.occurredAtMillis,
            lastNotifiedAtMillis = event.occurredAtMillis,
            firstNotifiedAtMillis = previous?.firstNotifiedAtMillis ?: event.occurredAtMillis,
            completedAtMillis = previous?.completedAtMillis,
            snoozedUntilMillis = null,
            nextAlarmAtMillis = previous?.nextAlarmAtMillis,
            notificationCount = (previous?.notificationCount ?: 0) + 1,
        )

    private fun TriggerTimeWindow.matches(epochMillis: Long): Boolean {
        val calendar =
            Calendar.getInstance(resolveTimeZone(timeZoneId)).apply {
                timeInMillis = epochMillis
            }
        val day = calendar.get(Calendar.DAY_OF_WEEK).toIsoWeekday()
        val minute = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)

        if (startMinuteOfDay == endMinuteOfDay) return day in daysOfWeek
        if (startMinuteOfDay < endMinuteOfDay) {
            return day in daysOfWeek && minute >= startMinuteOfDay && minute < endMinuteOfDay
        }
        if (minute >= startMinuteOfDay) return day in daysOfWeek
        return minute < endMinuteOfDay && previousDay(day) in daysOfWeek
    }

    private fun sameLocalDay(
        rule: TriggerRule,
        firstMillis: Long,
        secondMillis: Long,
    ): Boolean {
        val zone = resolveTimeZone(rule.timeZoneId())
        val first = Calendar.getInstance(zone).apply { timeInMillis = firstMillis }
        val second = Calendar.getInstance(zone).apply { timeInMillis = secondMillis }
        return first.get(Calendar.ERA) == second.get(Calendar.ERA) &&
            first.get(Calendar.YEAR) == second.get(Calendar.YEAR) &&
            first.get(Calendar.DAY_OF_YEAR) == second.get(Calendar.DAY_OF_YEAR)
    }

    private fun sameLocalWeek(
        rule: TriggerRule,
        firstMillis: Long,
        secondMillis: Long,
    ): Boolean {
        val zone = resolveTimeZone(rule.timeZoneId())
        val first = startOfIsoWeek(firstMillis, zone)
        val second = startOfIsoWeek(secondMillis, zone)
        return first == second
    }

    private fun startOfIsoWeek(
        epochMillis: Long,
        zone: TimeZone,
    ): Long =
        Calendar.getInstance(zone).run {
            firstDayOfWeek = Calendar.MONDAY
            minimalDaysInFirstWeek = 4
            timeInMillis = epochMillis
            set(Calendar.DAY_OF_WEEK, Calendar.MONDAY)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            timeInMillis
        }

    private fun TriggerRule.timeZoneId(): String? =
        timeWindow?.timeZoneId ?: alarmSchedule?.timeZoneId

    private fun resolveTimeZone(id: String?): TimeZone {
        return TriggerTimeZones.resolve(id)
    }

    private fun previousDay(day: Int): Int =
        if (day == TriggerTimeWindow.MONDAY) TriggerTimeWindow.SUNDAY else day - 1

    private fun Int.toIsoWeekday(): Int =
        if (this == Calendar.SUNDAY) TriggerTimeWindow.SUNDAY else this - 1

    private fun saturatedAdd(left: Long, right: Long): Long =
        if (right > Long.MAX_VALUE - left) Long.MAX_VALUE else left + right
}
