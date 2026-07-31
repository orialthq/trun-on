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
    val shareKind: String = SHARE_KIND_TEXT,
    val attachments: List<IncomingShareAttachment> = emptyList(),
)

data class IncomingShareAttachment(
    val id: String,
    val filePath: String,
    val mimeType: String,
    val byteSize: Long,
    val width: Int,
    val height: Int,
    val sha256: String,
)

object IncomingShareIntentParser {
    const val MAX_SHARED_TEXT_LENGTH = 100_000
    private val urlPattern = Regex("""https?://[^\s]+""")

    fun parse(
        intent: Intent?,
        sourcePackage: String? = null,
    ): IncomingSharePayload? {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") {
            return null
        }

        val parsedText = parseSharedText(intent)
        if (parsedText.originalWasBlank) {
            return null
        }

        return IncomingSharePayload(
            id = UUID.randomUUID().toString(),
            receivedAtEpochMs = System.currentTimeMillis(),
            sharedText = parsedText.sharedText,
            discoveredUrl = parsedText.discoveredUrl,
            sourcePackage = sourcePackage,
            mimeType = intent.type.orEmpty(),
            wasTruncated = parsedText.wasTruncated,
            originalLength = parsedText.originalLength,
            shareKind = SHARE_KIND_TEXT,
        )
    }

    fun parseSharedText(intent: Intent): ParsedSharedText {
        val originalText =
            intent
                .getCharSequenceExtra(Intent.EXTRA_TEXT)
                ?.toString()
                .orEmpty()
        val sharedText = originalText.take(MAX_SHARED_TEXT_LENGTH)
        return ParsedSharedText(
            sharedText = sharedText,
            discoveredUrl =
                urlPattern
                    .find(sharedText)
                    ?.value
                    ?.trimEnd(')', ',', '.', '!', '?', '\'', '"'),
            wasTruncated = originalText.length > sharedText.length,
            originalLength = originalText.length,
            originalWasBlank = originalText.isBlank(),
        )
    }
}

data class ParsedSharedText(
    val sharedText: String,
    val discoveredUrl: String?,
    val wasTruncated: Boolean,
    val originalLength: Int,
    val originalWasBlank: Boolean,
)

const val SHARE_KIND_TEXT = "text"
const val SHARE_KIND_IMAGE = "image"
