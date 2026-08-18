package com.orialthq.ori_beauty.trigger

import java.time.Instant
import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TriggerAlarmRecurrenceTest {
    @Test
    fun `daily keeps local wall clock across daylight saving transition`() {
        val zoneId = "America/New_York"
        val first = Instant.parse("2026-03-07T14:00:00Z").toEpochMilli() // 09:00 EST
        val next = requireNotNull(TriggerAlarmRecurrence.next(TriggerRecurrence.DAILY, first, zoneId))
        val local = Calendar.getInstance(TimeZone.getTimeZone(zoneId)).apply { timeInMillis = next }

        assertEquals(9, local.get(Calendar.HOUR_OF_DAY))
        assertEquals(8, local.get(Calendar.DAY_OF_MONTH))
        assertEquals(23 * 60 * 60 * 1_000L, next - first)
    }

    @Test
    fun `weekly advances seven local calendar days`() {
        val zoneId = "Asia/Seoul"
        val first = Instant.parse("2026-08-17T00:30:00Z").toEpochMilli()
        val next = requireNotNull(TriggerAlarmRecurrence.next(TriggerRecurrence.WEEKLY, first, zoneId))

        assertEquals(7 * 24 * 60 * 60 * 1_000L, next - first)
    }

    @Test
    fun `once has no next occurrence`() {
        assertNull(TriggerAlarmRecurrence.next(TriggerRecurrence.ONCE, 100, "UTC"))
    }

    @Test
    fun `first recurring occurrence skips missed periods`() {
        assertEquals(
            100 + 3 * 24 * 60 * 60 * 1_000L,
            TriggerAlarmRecurrence.firstAtOrAfter(
                recurrence = TriggerRecurrence.DAILY,
                firstFireAtMillis = 100,
                thresholdMillis = 100 + 2 * 24 * 60 * 60 * 1_000L + 1,
                timeZoneId = "UTC",
            ),
        )
    }
}
