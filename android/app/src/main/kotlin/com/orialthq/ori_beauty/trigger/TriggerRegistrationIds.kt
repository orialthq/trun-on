package com.orialthq.ori_beauty.trigger

import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.security.MessageDigest

/** Stable platform identifiers that do not expose or truncate user/content ids. */
object TriggerRegistrationIds {
    fun geofenceRequestId(ruleId: String): String =
        "native-trigger-v1:${digest(ruleId).take(GEOFENCE_DIGEST_CHARACTERS)}"

    fun notificationId(ruleId: String): Int = positiveInt("notification:$ruleId")

    fun pendingIntentRequestCode(
        ruleId: String,
        purpose: String,
    ): Int = positiveInt("$purpose:$ruleId")

    private fun positiveInt(value: String): Int {
        val bytes = sha256(value)
        return ByteBuffer.wrap(bytes, 0, Int.SIZE_BYTES).int and Int.MAX_VALUE
    }

    private fun digest(value: String): String =
        sha256(value).joinToString(separator = "") { byte ->
            "%02x".format(byte.toInt() and 0xff)
        }

    private fun sha256(value: String): ByteArray =
        MessageDigest
            .getInstance("SHA-256")
            .digest(value.toByteArray(StandardCharsets.UTF_8))

    private const val GEOFENCE_DIGEST_CHARACTERS = 40
}
