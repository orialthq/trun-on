package com.orialthq.ori_beauty.trigger

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TriggerRuleWireCodecTest {
    @Test
    fun `decodes complete Flutter rule contract`() {
        val rule =
            TriggerRuleWireCodec.decodeRule(
                mapOf(
                    "id" to "rule-1",
                    "destinationId" to "capture-7",
                    "title" to "저장한 곳 근처야",
                    "message" to "지금 확인해 봐",
                    "latitude" to 37.5,
                    "longitude" to 127.0,
                    "radiusMeters" to 250,
                    "enabled" to true,
                    "timeWindow" to
                        mapOf(
                            "daysOfWeek" to
                                listOf(TriggerTimeWindow.MONDAY, TriggerTimeWindow.FRIDAY),
                            "startMinuteOfDay" to 600,
                            "endMinuteOfDay" to 840,
                            "timeZoneId" to "Asia/Seoul",
                        ),
                    "cooldownMillis" to 10_000,
                    "dedupeWindowMillis" to 2_000,
                    "recurrence" to "once",
                    "laterDelayMillis" to 30_000,
                    "createdAtMillis" to 100,
                    "updatedAtMillis" to 200,
                ),
            )

        assertEquals("capture-7", rule.destinationId)
        assertEquals(TriggerRecurrence.ONCE, rule.recurrence)
        assertEquals(
            setOf(TriggerTimeWindow.MONDAY, TriggerTimeWindow.FRIDAY),
            rule.timeWindow?.daysOfWeek,
        )
        assertEquals(600, rule.timeWindow?.startMinuteOfDay)
        assertEquals(10_000, rule.cooldownMillis)
    }

    @Test
    fun `defaults optional fields without inventing a time window`() {
        val rule =
            TriggerRuleWireCodec.decodeRule(
                mapOf(
                    "id" to "rule-1",
                    "title" to "알림",
                    "latitude" to 37.5,
                    "longitude" to 127.0,
                    "radiusMeters" to 500,
                ),
                nowMillis = 123,
            )

        assertEquals("rule-1", rule.destinationId)
        assertEquals(123, rule.createdAtMillis)
        assertEquals(123, rule.updatedAtMillis)
        assertEquals(TriggerRecurrence.ON_REENTRY, rule.recurrence)
        assertNull(rule.timeWindow)
    }

    @Test
    fun `decodes time-only daily alarm`() {
        val rule =
            TriggerRuleWireCodec.decodeRule(
                mapOf(
                    "id" to "morning",
                    "destinationId" to "capture-9",
                    "title" to "챙길 시간이야",
                    "alarmSchedule" to
                        mapOf(
                            "firstFireAtMillis" to 1_800_000,
                            "timeZoneId" to "Asia/Seoul",
                        ),
                    "recurrence" to "daily",
                ),
                nowMillis = 123,
            )

        assertNull(rule.location)
        assertEquals(1_800_000L, rule.alarmSchedule?.firstFireAtMillis)
        assertEquals(TriggerRecurrence.DAILY, rule.recurrence)
    }
}
