package com.orialthq.ori_beauty.trigger

import android.content.Context
import android.location.Address
import android.location.Geocoder
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.io.Closeable
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

data class ResolvedTriggerLocation(
    val latitude: Double,
    val longitude: Double,
    val formattedAddress: String,
)

/** Geocoder wrapper that never blocks Flutter's platform thread. */
class TriggerLocationResolver(context: Context) : Closeable {
    private val geocoder = Geocoder(context.applicationContext, Locale.KOREA)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    fun resolve(
        query: String,
        callback: (ResolvedTriggerLocation?) -> Unit,
    ) {
        val normalized = query.trim()
        if (normalized.isEmpty() || !Geocoder.isPresent()) {
            callback(null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            runCatching {
                geocoder.getFromLocationName(
                    normalized,
                    1,
                    object : Geocoder.GeocodeListener {
                        override fun onGeocode(addresses: MutableList<Address>) {
                            mainHandler.post {
                                callback(addresses.firstOrNull()?.toResolved(normalized))
                            }
                        }

                        override fun onError(errorMessage: String?) {
                            mainHandler.post { callback(null) }
                        }
                    },
                )
            }.onFailure { mainHandler.post { callback(null) } }
            return
        }
        executor.execute {
            @Suppress("DEPRECATION")
            val address =
                runCatching { geocoder.getFromLocationName(normalized, 1)?.firstOrNull() }
                    .getOrNull()
            mainHandler.post { callback(address?.toResolved(normalized)) }
        }
    }

    override fun close() {
        executor.shutdownNow()
    }

    private fun Address.toResolved(fallbackAddress: String): ResolvedTriggerLocation =
        ResolvedTriggerLocation(
            latitude = latitude,
            longitude = longitude,
            formattedAddress =
                runCatching { getAddressLine(0) }
                    .getOrNull()
                    ?.trim()
                    ?.takeIf(String::isNotEmpty)
                    ?: fallbackAddress,
        )
}
