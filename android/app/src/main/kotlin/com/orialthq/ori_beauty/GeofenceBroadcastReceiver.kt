package com.orialthq.ori_beauty

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError() || event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_ENTER) {
            return
        }
        val store = PlaceReminderStore(context)
        event.triggeringGeofences.orEmpty().forEach { geofence ->
            val reminder = store.find(geofence.requestId) ?: return@forEach
            showNotification(context, reminder)
        }
    }

    private fun showNotification(context: Context, reminder: StoredPlaceReminder) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "저장한 장소 알림",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "저장한 장소의 설정 반경 안에 들어오면 알려드려요."
                },
            )
        }
        val openApp =
            PendingIntent.getActivity(
                context,
                reminder.id.hashCode(),
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
            }
        manager.notify(
            reminder.id.hashCode(),
            builder
                .setSmallIcon(com.orialthq.ori_beauty.R.drawable.ic_chaengim_tile)
                .setContentTitle("${reminder.title} 근처예요")
                .setContentText("저장해 둔 장소를 확인해 보세요.")
                .setCategory(Notification.CATEGORY_REMINDER)
                .setContentIntent(openApp)
                .setAutoCancel(true)
                .build(),
        )
    }

    companion object {
        private const val CHANNEL_ID = "saved_place_arrivals_v1"
    }
}
