package com.orialthq.ori_beauty.trigger

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class TriggerGeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError() || event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_ENTER) {
            return
        }
        val scheduler = NativeTriggerScheduler(context)
        val occurredAt = System.currentTimeMillis()
        event.triggeringGeofences.orEmpty().forEach { geofence ->
            scheduler.handleGeofenceEntry(geofence.requestId, occurredAt)
        }
    }
}
