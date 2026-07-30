package com.orialthq.ori_beauty.share

import android.content.Intent
import java.util.UUID

data class IncomingSharePayload(
    val id: String,
    val receivedAtEpochMs: Long,
    val sharedText: String,
    val discoveredUrl: String?,
)

object IncomingShareIntentParser {
    private const val MAX_SHARED_TEXT_LENGTH = 20_000
    private val urlPattern = Regex("""https?://[^\s]+""")

    fun parse(intent: Intent?): IncomingSharePayload? {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") {
            return null
        }

        val sharedText =
            intent
                .getCharSequenceExtra(Intent.EXTRA_TEXT)
                ?.toString()
                ?.trim()
                ?.take(MAX_SHARED_TEXT_LENGTH)
                .orEmpty()

        if (sharedText.isBlank()) {
            return null
        }

        return IncomingSharePayload(
            id = UUID.randomUUID().toString(),
            receivedAtEpochMs = System.currentTimeMillis(),
            sharedText = sharedText,
            discoveredUrl =
                urlPattern
                    .find(sharedText)
                    ?.value
                    ?.trimEnd(')', ',', '.', '!', '?', '\'', '"'),
        )
    }
}
