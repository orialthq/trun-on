package com.orialthq.ori_beauty.trigger

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TriggerRegistrationIdsTest {
    @Test
    fun `geofence request id is stable bounded and opaque`() {
        val longSensitiveId = "capture/" + "가나다라".repeat(100)
        val result = TriggerRegistrationIds.geofenceRequestId(longSensitiveId)

        assertEquals(result, TriggerRegistrationIds.geofenceRequestId(longSensitiveId))
        assertTrue(result.length <= 100)
        assertTrue(result.startsWith("native-trigger-v1:"))
        assertTrue(!result.contains("capture"))
    }

    @Test
    fun `platform ids separate rules and pending intent purposes`() {
        assertNotEquals(
            TriggerRegistrationIds.geofenceRequestId("rule-a"),
            TriggerRegistrationIds.geofenceRequestId("rule-b"),
        )
        assertNotEquals(
            TriggerRegistrationIds.pendingIntentRequestCode("rule-a", "done"),
            TriggerRegistrationIds.pendingIntentRequestCode("rule-a", "later"),
        )
        assertTrue(TriggerRegistrationIds.notificationId("rule-a") >= 0)
    }
}
