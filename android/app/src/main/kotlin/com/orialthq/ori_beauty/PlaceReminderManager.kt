package com.orialthq.ori_beauty

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.location.Address
import android.location.Geocoder
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import java.util.Locale
import java.util.concurrent.Executors

class PlaceReminderManager(private val context: Context) {
    private val store = PlaceReminderStore(context)
    private val geofencingClient = LocationServices.getGeofencingClient(context)
    private val mainHandler = Handler(Looper.getMainLooper())

    fun state(id: String): Map<String, Any> {
        val reminder = store.find(id)
        return mapOf(
            "enabled" to (reminder != null),
            "radiusMeters" to (reminder?.radiusMeters?.toDouble() ?: DEFAULT_RADIUS_METERS),
        )
    }

    @SuppressLint("MissingPermission")
    fun enable(
        id: String,
        title: String,
        address: String,
        radiusMeters: Float,
        callback: (Result<StoredPlaceReminder>) -> Unit,
    ) {
        geocode(address) { geocoded ->
            if (geocoded == null) {
                callback(Result.failure(IllegalArgumentException("address_not_found")))
                return@geocode
            }
            val reminder =
                StoredPlaceReminder(
                    id = id,
                    title = title,
                    address = address,
                    latitude = geocoded.latitude,
                    longitude = geocoded.longitude,
                    radiusMeters = radiusMeters.coerceIn(MIN_RADIUS_METERS, MAX_RADIUS_METERS),
                )
            geofencingClient
                .addGeofences(requestFor(listOf(reminder)), geofencePendingIntent())
                .addOnSuccessListener {
                    if (store.upsert(reminder)) {
                        callback(Result.success(reminder))
                    } else {
                        geofencingClient.removeGeofences(listOf(reminder.id))
                        callback(Result.failure(IllegalStateException("reminder_save_failed")))
                    }
                }
                .addOnFailureListener { error -> callback(Result.failure(error)) }
        }
    }

    fun disable(id: String, callback: (Boolean) -> Unit) {
        geofencingClient
            .removeGeofences(listOf(id))
            .addOnCompleteListener { callback(store.remove(id)) }
    }

    @SuppressLint("MissingPermission")
    fun registerAll() {
        val reminders = store.all()
        if (reminders.isEmpty()) {
            return
        }
        runCatching {
            geofencingClient.addGeofences(
                requestFor(reminders),
                geofencePendingIntent(),
            )
        }
    }

    private fun requestFor(reminders: List<StoredPlaceReminder>): GeofencingRequest {
        val geofences =
            reminders.map { reminder ->
                Geofence.Builder()
                    .setRequestId(reminder.id)
                    .setCircularRegion(
                        reminder.latitude,
                        reminder.longitude,
                        reminder.radiusMeters,
                    )
                    .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
                    .setExpirationDuration(Geofence.NEVER_EXPIRE)
                    .build()
            }
        return GeofencingRequest.Builder().addGeofences(geofences).build()
    }

    private fun geofencePendingIntent(): PendingIntent {
        val intent = Intent(context, GeofenceBroadcastReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            GEOFENCE_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    }

    private fun geocode(address: String, callback: (Address?) -> Unit) {
        if (!Geocoder.isPresent()) {
            callback(null)
            return
        }
        val geocoder = Geocoder(context, Locale.KOREA)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            geocoder.getFromLocationName(
                address,
                1,
                object : Geocoder.GeocodeListener {
                    override fun onGeocode(addresses: MutableList<Address>) {
                        mainHandler.post { callback(addresses.firstOrNull()) }
                    }

                    override fun onError(errorMessage: String?) {
                        mainHandler.post { callback(null) }
                    }
                },
            )
            return
        }
        Executors.newSingleThreadExecutor().execute {
            @Suppress("DEPRECATION")
            val result = runCatching { geocoder.getFromLocationName(address, 1) }.getOrNull()
            mainHandler.post { callback(result?.firstOrNull()) }
        }
    }

    companion object {
        const val DEFAULT_RADIUS_METERS = 500.0
        const val MIN_RADIUS_METERS = 100f
        const val MAX_RADIUS_METERS = 5_000f
        private const val GEOFENCE_REQUEST_CODE = 4110
    }
}
