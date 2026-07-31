package com.orialthq.ori_beauty.share

import android.content.Intent
import java.util.UUID

data class IncomingSharePayload(
    val id: String,
    val receivedAtEpochMs: Long,
    val sharedText: String,
    val discoveredUrl: String?,
    val sourcePackage: String?,
    val mimeType: String,
    val wasTruncated: Boolean,
    val originalLength: Int,
)

object IncomingShareIntentParser {
    private const val MAX_SHARED_TEXT_LENGTH = 100_000
    private val urlPattern = Regex("""https?://[^\s]+""")

    fun parse(
        intent: Intent?,
        sourcePackage: String? = null,
    ): IncomingSharePayload? {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") {
            return null
        }

        val originalText =
            intent
                .getCharSequenceExtra(Intent.EXTRA_TEXT)
                ?.toString()
                .orEmpty()

        if (originalText.isBlank()) {
            return null
        }
        val sharedText = originalText.take(MAX_SHARED_TEXT_LENGTH)

        return IncomingSharePayload(
            id = UUID.randomUUID().toString(),
            receivedAtEpochMs = System.currentTimeMillis(),
            sharedText = sharedText,
            discoveredUrl =
                urlPattern
                    .find(sharedText)
                    ?.value
                    ?.trimEnd(')', ',', '.', '!', '?', '\'', '"'),
            sourcePackage = sourcePackage,
            mimeType = intent.type.orEmpty(),
            wasTruncated = originalText.length > sharedText.length,
            originalLength = originalText.length,
        )
    }
}
