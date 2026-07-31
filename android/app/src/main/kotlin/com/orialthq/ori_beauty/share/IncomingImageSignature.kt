package com.orialthq.ori_beauty.share

internal data class IncomingImageFormat(
    val mimeType: String,
    val extension: String,
)

internal object IncomingImageSignature {
    private val jpeg = IncomingImageFormat("image/jpeg", "jpg")
    private val png = IncomingImageFormat("image/png", "png")
    private val webp = IncomingImageFormat("image/webp", "webp")

    fun detect(header: ByteArray): IncomingImageFormat? {
        if (
            header.size >= 3 &&
            header[0].unsigned() == 0xff &&
            header[1].unsigned() == 0xd8 &&
            header[2].unsigned() == 0xff
        ) {
            return jpeg
        }

        if (
            header.size >= 8 &&
            header[0].unsigned() == 0x89 &&
            header[1].unsigned() == 0x50 &&
            header[2].unsigned() == 0x4e &&
            header[3].unsigned() == 0x47 &&
            header[4].unsigned() == 0x0d &&
            header[5].unsigned() == 0x0a &&
            header[6].unsigned() == 0x1a &&
            header[7].unsigned() == 0x0a
        ) {
            return png
        }

        if (
            header.size >= 12 &&
            header.copyOfRange(0, 4).decodeToString() == "RIFF" &&
            header.copyOfRange(8, 12).decodeToString() == "WEBP"
        ) {
            return webp
        }

        return null
    }

    private fun Byte.unsigned(): Int = toInt() and 0xff
}
