package com.orialthq.ori_beauty

import android.app.PendingIntent
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.MediaStore

class SharedMediaDeletionManager(private val context: Context) {
    private val sourceUris = LinkedHashMap<String, List<Uri>>()

    @Synchronized
    fun remember(
        transportId: String,
        sharedUris: List<Uri>,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return
        }
        val mediaUris =
            sharedUris
                .mapNotNull(::toMediaStoreUri)
                .distinctBy(Uri::toString)
        if (mediaUris.isEmpty()) {
            return
        }
        sourceUris[transportId] = mediaUris
        while (sourceUris.size > MAX_PENDING_SOURCES) {
            sourceUris.remove(sourceUris.keys.first())
        }
    }

    @Synchronized
    fun isAvailable(transportId: String): Boolean =
        sourceUris[transportId]?.isNotEmpty() == true

    @Synchronized
    fun createDeleteRequest(transportId: String): PendingIntent? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return null
        }
        val uris = sourceUris[transportId] ?: return null
        return runCatching {
            MediaStore.createDeleteRequest(context.contentResolver, uris)
        }.getOrNull()
    }

    @Synchronized
    fun forget(transportId: String) {
        sourceUris.remove(transportId)
    }

    private fun toMediaStoreUri(uri: Uri): Uri? {
        if (uri.scheme != "content") {
            return null
        }
        if (uri.authority == MediaStore.AUTHORITY) {
            return uri
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return null
        }
        return runCatching { MediaStore.getMediaUri(context, uri) }.getOrNull()
    }

    companion object {
        private const val MAX_PENDING_SOURCES = 20
    }
}
