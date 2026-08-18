package com.orialthq.ori_beauty.trigger

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import com.orialthq.ori_beauty.MainActivity
import com.orialthq.ori_beauty.R

class TriggerNotificationPresenter(context: Context) {
    private val applicationContext = context.applicationContext
    private val notificationManager =
        applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun canNotify(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            applicationContext.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    fun show(rule: TriggerRule): Boolean {
        if (!canNotify()) return false
        createChannel()
        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(applicationContext, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(applicationContext).setPriority(Notification.PRIORITY_HIGH)
            }
        notificationManager.notify(
            TriggerRegistrationIds.notificationId(rule.id),
            builder
                .setSmallIcon(R.drawable.ic_chaengim_tile)
                .setContentTitle(rule.title)
                .setContentText(rule.message)
                .setStyle(Notification.BigTextStyle().bigText(rule.message))
                .setCategory(Notification.CATEGORY_REMINDER)
                .setContentIntent(openDestinationIntent(rule))
                .addAction(
                    Notification.Action.Builder(
                        null,
                        "완료",
                        actionIntent(rule.id, TriggerNotificationActionReceiver.ACTION_DONE),
                    ).build(),
                )
                .addAction(
                    Notification.Action.Builder(
                        null,
                        "나중에",
                        actionIntent(rule.id, TriggerNotificationActionReceiver.ACTION_LATER),
                    ).build(),
                )
                .setAutoCancel(true)
                .build(),
        )
        return true
    }

    fun cancel(ruleId: String) {
        notificationManager.cancel(TriggerRegistrationIds.notificationId(ruleId))
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        notificationManager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "장소와 시간 알림",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "설정한 장소와 시간 조건이 맞으면 저장한 내용을 알려줘요."
            },
        )
    }

    private fun openDestinationIntent(rule: TriggerRule): PendingIntent =
        PendingIntent.getActivity(
            applicationContext,
            TriggerRegistrationIds.pendingIntentRequestCode(rule.id, "open"),
            Intent(applicationContext, MainActivity::class.java).apply {
                action = ACTION_OPEN_NATIVE_TRIGGER
                data = triggerUri("open", rule.id)
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(EXTRA_TRIGGER_RULE_ID, rule.id)
                putExtra(EXTRA_TRIGGER_DESTINATION_ID, rule.destinationId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun actionIntent(
        ruleId: String,
        action: String,
    ): PendingIntent =
        PendingIntent.getBroadcast(
            applicationContext,
            TriggerRegistrationIds.pendingIntentRequestCode(ruleId, action),
            Intent(applicationContext, TriggerNotificationActionReceiver::class.java).apply {
                this.action = action
                data = triggerUri(action.substringAfterLast('.'), ruleId)
                putExtra(TriggerNotificationActionReceiver.EXTRA_RULE_ID, ruleId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    companion object {
        const val ACTION_OPEN_NATIVE_TRIGGER =
            "com.orialthq.ori_beauty.action.OPEN_NATIVE_TRIGGER"
        const val EXTRA_TRIGGER_RULE_ID = "native_trigger_rule_id"
        const val EXTRA_TRIGGER_DESTINATION_ID = "native_trigger_destination_id"
        private const val CHANNEL_ID = "native_triggers_v1"

        internal fun triggerUri(
            purpose: String,
            ruleId: String,
        ): Uri =
            Uri.Builder()
                .scheme("orialt-trigger")
                .authority(purpose)
                .appendPath(ruleId)
                .build()
    }
}
