package com.orialthq.ori_beauty.trigger

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

class TriggerAlarmScheduler(context: Context) {
    private val applicationContext = context.applicationContext
    private val alarmManager =
        applicationContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    /**
     * [scheduledAtMillis] is persisted in the PendingIntent so an obsolete alarm can be rejected.
     * [fireAtMillis] may be later when a past-due alarm is restored after a reboot.
     */
    fun schedule(
        ruleId: String,
        scheduledAtMillis: Long,
        fireAtMillis: Long = scheduledAtMillis,
    ) {
        val operation = pendingIntent(ruleId, scheduledAtMillis)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                fireAtMillis,
                operation,
            )
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, fireAtMillis, operation)
        }
    }

    fun cancel(
        ruleId: String,
        scheduledAtMillis: Long?,
    ) {
        if (scheduledAtMillis == null) return
        alarmManager.cancel(pendingIntent(ruleId, scheduledAtMillis))
    }

    fun scheduleTime(
        ruleId: String,
        scheduledAtMillis: Long,
        fireAtMillis: Long = scheduledAtMillis,
    ) {
        val operation = timePendingIntent(ruleId, scheduledAtMillis)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAtMillis, operation)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, fireAtMillis, operation)
        }
    }

    fun cancelTime(
        ruleId: String,
        scheduledAtMillis: Long?,
    ) {
        if (scheduledAtMillis == null) return
        alarmManager.cancel(timePendingIntent(ruleId, scheduledAtMillis))
    }

    private fun pendingIntent(
        ruleId: String,
        scheduledAtMillis: Long,
    ): PendingIntent =
        PendingIntent.getBroadcast(
            applicationContext,
            TriggerRegistrationIds.pendingIntentRequestCode(ruleId, "snooze"),
            Intent(applicationContext, TriggerNotificationActionReceiver::class.java).apply {
                action = TriggerNotificationActionReceiver.ACTION_SNOOZE_DUE
                data = TriggerNotificationPresenter.triggerUri("snooze", ruleId)
                putExtra(TriggerNotificationActionReceiver.EXTRA_RULE_ID, ruleId)
                putExtra(
                    TriggerNotificationActionReceiver.EXTRA_SCHEDULED_AT_MILLIS,
                    scheduledAtMillis,
                )
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun timePendingIntent(
        ruleId: String,
        scheduledAtMillis: Long,
    ): PendingIntent =
        PendingIntent.getBroadcast(
            applicationContext,
            TriggerRegistrationIds.pendingIntentRequestCode(ruleId, "scheduled-time"),
            Intent(applicationContext, TriggerNotificationActionReceiver::class.java).apply {
                action = TriggerNotificationActionReceiver.ACTION_TIME_DUE
                data = TriggerNotificationPresenter.triggerUri("scheduled-time", ruleId)
                putExtra(TriggerNotificationActionReceiver.EXTRA_RULE_ID, ruleId)
                putExtra(
                    TriggerNotificationActionReceiver.EXTRA_SCHEDULED_AT_MILLIS,
                    scheduledAtMillis,
                )
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}
