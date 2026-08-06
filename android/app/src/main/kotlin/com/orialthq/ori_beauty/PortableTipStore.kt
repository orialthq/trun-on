package com.orialthq.ori_beauty

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

/** Durable, acknowledge-after-save inbox for small cross-platform tip files. */
class PortableTipStore(private val context: Context) {
    private val directory = File(context.noBackupFilesDir, DIRECTORY_NAME)

    fun stage(intent: Intent?): String? {
        if (!isPortableIntent(intent)) return null
        val uri = extractUri(intent ?: return null) ?: return null
        if (uri.scheme != ContentResolver.SCHEME_CONTENT) return null
        if (!directory.exists() && !directory.mkdirs()) return null

        val transportId = UUID.randomUUID().toString()
        val temporary = File(directory, ".$transportId.part")
        val destination = File(directory, "$transportId.$FILE_EXTENSION")
        return try {
            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(temporary).use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var total = 0
                    while (true) {
                        val read = input.read(buffer)
                        if (read == -1) break
                        total += read
                        if (total > MAX_PACKAGE_BYTES) throw InvalidPortableTipException()
                        output.write(buffer, 0, read)
                    }
                    if (total == 0) throw InvalidPortableTipException()
                    output.fd.sync()
                }
            } ?: throw InvalidPortableTipException()
            if (!temporary.renameTo(destination)) throw InvalidPortableTipException()
            transportId
        } catch (_: Exception) {
            temporary.delete()
            destination.delete()
            null
        }
    }

    fun pending(): List<Map<String, String>> {
        if (!directory.exists()) return emptyList()
        return directory
            .listFiles { file ->
                file.isFile &&
                    file.extension == FILE_EXTENSION &&
                    TRANSPORT_ID.matches(file.nameWithoutExtension) &&
                    file.length() in 1..MAX_PACKAGE_BYTES.toLong()
            }
            .orEmpty()
            .sortedBy { it.lastModified() }
            .mapNotNull { file ->
                runCatching {
                    mapOf(
                        "transportId" to file.nameWithoutExtension,
                        "contents" to file.readText(Charsets.UTF_8),
                    )
                }.getOrNull()
            }
    }

    fun acknowledge(transportIds: Collection<String>) {
        if (!directory.exists()) return
        transportIds
            .filter(TRANSPORT_ID::matches)
            .forEach { transportId ->
                File(directory, "$transportId.$FILE_EXTENSION").delete()
            }
    }

    fun isPortableIntent(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_SEND && intent?.action != Intent.ACTION_VIEW) {
            return false
        }
        if (intent.type == MIME_TYPE) return true
        return extractUri(intent)?.lastPathSegment
            ?.substringBefore('?')
            ?.endsWith(".$FILE_EXTENSION", ignoreCase = true) == true
    }

    private fun extractUri(intent: Intent): Uri? {
        if (intent.action == Intent.ACTION_VIEW) return intent.data
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }
    }

    private class InvalidPortableTipException : Exception()

    companion object {
        const val MIME_TYPE = "application/vnd.orialthq.trunon.tip+json"
        const val FILE_EXTENSION = "trunon"
        const val MAX_PACKAGE_BYTES = 64 * 1024
        private const val DIRECTORY_NAME = "portable_tip_inbox"
        private val TRANSPORT_ID = Regex("^[0-9a-f-]{36}$")
    }
}
