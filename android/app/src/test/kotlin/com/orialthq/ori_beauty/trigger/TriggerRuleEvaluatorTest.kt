package com.orialthq.ori_beauty.trigger

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TriggerRuleEvaluatorTest {
    @Test
    fun `allows an eligible first geofence entry`() {
        val rule = rule()
        val event = TriggerEvent.geofenceEntry(rule, instant("2026-08-17T12:00:00Z"))

        assertEquals(TriggerDecision.Notify, TriggerRuleEvaluator.evaluate(rule, null, event))
    }

    @Test
    fun `dedupes a redelivered event even when cooldown is zero`() {
        val rule = rule(cooldownMillis = 0)
        val event = TriggerEvent.geofenceEntry(rule, instant("2026-08-17T12:00:00Z"))
        val state = TriggerRuleEvaluator.stateAfterNotification(rule, null, event)

        assertEquals(
            TriggerDecision.Suppress(TriggerSuppressionReason.DUPLICATE_EVENT),
            TriggerRuleEvaluator.evaluate(rule, state, event),
        )
    }

    @Test
    fun `suppresses distinct entries during cooldown then allows the boundary`() {
        val rule = rule(cooldownMillis = 60_000, dedupeWindowMillis = 1_000)
        val first = TriggerEvent.geofenceEntry(rule, 100_000)
        val state = TriggerRuleEvaluator.stateAfterNotification(rule, null, first)

        assertEquals(
            TriggerDecision.Suppress(TriggerSuppressionReason.COOLDOWN),
            TriggerRuleEvaluator.evaluate(rule, state, TriggerEvent.geofenceEntry(rule, 159_999)),
        )
        assertEquals(
            TriggerDecision.Notify,
            TriggerRuleEvaluator.evaluate(rule, state, TriggerEvent.geofenceEntry(rule, 160_000)),
        )
    }

    @Test
    fun `once rule stays suppressed after its first notification`() {
        val rule = rule(recurrence = TriggerRecurrence.ONCE, cooldownMillis = 0)
        val first = TriggerEvent.geofenceEntry(rule, 100_000)
        val state = TriggerRuleEvaluator.stateAfterNotification(rule, null, first)

        assertEquals(
            TriggerDecision.Suppress(TriggerSuppressionReason.ONCE_ALREADY_FIRED),
            TriggerRuleEvaluator.evaluate(rule, state, TriggerEvent.geofenceEntry(rule, 200_000)),
        )
    }

    @Test
    fun `snooze blocks new entries until its exact due time`() {
        val rule = rule(cooldownMillis = 0)
        val state = TriggerRuntimeState(ruleId = rule.id, snoozedUntilMillis = 200_000)

        assertEquals(
            TriggerDecision.Suppress(TriggerSuppressionReason.SNOOZED),
            TriggerRuleEvaluator.evaluate(rule, state, TriggerEvent.geofenceEntry(rule, 199_999)),
        )
        assertEquals(
            TriggerDecision.Notify,
            TriggerRuleEvaluator.evaluate(rule, state, TriggerEvent.geofenceEntry(rule, 200_000)),
        )
    }

    @Test
    fun `matches normal time window with an exclusive end`() {
        val rule =
            rule(
                timeWindow =
                    TriggerTimeWindow(
                        daysOfWeek = setOf(TriggerTimeWindow.MONDAY),
                        startMinuteOfDay = 9 * 60,
                        endMinuteOfDay = 18 * 60,
                        timeZoneId = "Asia/Seoul",
                    ),
            )

        assertTrue(notifies(rule, "2026-08-17T00:00:00Z")) // Monday 09:00 KST
        assertSuppressed(rule, "2026-08-17T09:00:00Z", TriggerSuppressionReason.OUTSIDE_TIME_WINDOW)
    }

    @Test
    fun `overnight window attributes after-midnight portion to previous day`() {
        val rule =
            rule(
                timeWindow =
                    TriggerTimeWindow(
                        daysOfWeek = setOf(TriggerTimeWindow.MONDAY),
                        startMinuteOfDay = 22 * 60,
                        endMinuteOfDay = 2 * 60,
                        timeZoneId = "Asia/Seoul",
                    ),
            )

        assertTrue(notifies(rule, "2026-08-17T13:00:00Z")) // Monday 22:00 KST
        assertTrue(notifies(rule, "2026-08-17T16:59:00Z")) // Tuesday 01:59 KST
        assertSuppressed(rule, "2026-08-17T17:00:00Z", TriggerSuppressionReason.OUTSIDE_TIME_WINDOW)
    }

    @Test
    fun `completed rule always stays suppressed`() {
        val rule = rule()
        val state = TriggerRuntimeState(ruleId = rule.id, completedAtMillis = 123)

        assertEquals(
            TriggerDecision.Suppress(TriggerSuppressionReason.COMPLETED),
            TriggerRuleEvaluator.evaluate(rule, state, TriggerEvent.geofenceEntry(rule, 999_999)),
        )
    }

    @Test
    fun `daily recurrence uses the configured local calendar day`() {
        val rule =
            rule(
                recurrence = TriggerRecurrence.DAILY,
                cooldownMillis = 0,
                timeWindow =
                    TriggerTimeWindow(
                        startMinuteOfDay = 0,
                        endMinuteOfDay = 0,
                        timeZoneId = "Asia/Seoul",
                    ),
            )
        val first = TriggerEvent.geofenceEntry(rule, instant("2026-08-16T15:30:00Z"))
        val state = TriggerRuleEvaluator.stateAfterNotification(rule, null, first)

        assertEquals(
            TriggerDecision.Suppress(TriggerSuppressionReason.DAILY_ALREADY_FIRED),
            TriggerRuleEvaluator.evaluate(
                rule,
                state,
                TriggerEvent.geofenceEntry(rule, instant("2026-08-17T14:59:00Z")),
            ),
        )
        assertEquals(
            TriggerDecision.Notify,
            TriggerRuleEvaluator.evaluate(
                rule,
                state,
                TriggerEvent.geofenceEntry(rule, instant("2026-08-17T15:00:00Z")),
            ),
        )
    }

    private fun notifies(rule: TriggerRule, value: String): Boolean =
        TriggerRuleEvaluator.evaluate(
            rule,
            null,
            TriggerEvent.geofenceEntry(rule, instant(value)),
        ) == TriggerDecision.Notify

    private fun assertSuppressed(
        rule: TriggerRule,
        value: String,
        reason: TriggerSuppressionReason,
    ) {
        assertEquals(
            TriggerDecision.Suppress(reason),
            TriggerRuleEvaluator.evaluate(
                rule,
                null,
                TriggerEvent.geofenceEntry(rule, instant(value)),
            ),
        )
    }

    private fun rule(
        cooldownMillis: Long = TriggerRule.DEFAULT_COOLDOWN_MILLIS,
        dedupeWindowMillis: Long = TriggerRule.DEFAULT_DEDUPE_WINDOW_MILLIS,
        recurrence: TriggerRecurrence = TriggerRecurrence.ON_REENTRY,
        timeWindow: TriggerTimeWindow? = null,
    ): TriggerRule =
        TriggerRule(
            id = "rule-1",
            destinationId = "capture-1",
            title = "근처에 저장한 장소가 있어",
            message = "지금 확인해 봐",
            location = TriggerLocation(37.5665, 126.9780, 300f),
            cooldownMillis = cooldownMillis,
            dedupeWindowMillis = dedupeWindowMillis,
            recurrence = recurrence,
            timeWindow = timeWindow,
            createdAtMillis = 1,
            updatedAtMillis = 1,
        )

    private fun instant(value: String): Long = Instant.parse(value).toEpochMilli()
}
