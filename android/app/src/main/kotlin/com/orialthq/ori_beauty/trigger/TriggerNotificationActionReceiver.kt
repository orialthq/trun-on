package com.orialthq.ori_beauty.trigger

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class TriggerNotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        val ruleId = intent.getStringExtra(EXTRA_RULE_ID)?.trim().orEmpty()
        if (ruleId.isEmpty()) return
        val scheduler = NativeTriggerScheduler(context)
        val interactions = TriggerInteractionStore(context)
        val now = System.currentTimeMillis()
        when (intent.action) {
            ACTION_DONE -> {
                val pendingResult = goAsync()
                scheduler.complete(ruleId, completedAtMillis = now) { saved ->
                    if (saved) {
                        interactions.enqueueOutcome(
                            ruleId = ruleId,
                            kind = TriggerOutcomeKind.DONE,
                            occurredAtMillis = now,
                        )
                    }
                    pendingResult.finish()
                }
            }
            ACTION_LATER -> {
                if (scheduler.snooze(ruleId, requestedAtMillis = now)) {
                    interactions.enqueueOutcome(
                        ruleId = ruleId,
                        kind = TriggerOutcomeKind.LATER,
                        occurredAtMillis = now,
                        snoozedUntilMillis = scheduler.state(ruleId)?.snoozedUntilMillis,
                    )
                }
            }
            ACTION_SNOOZE_DUE -> {
                val scheduledAt = intent.getLongExtra(EXTRA_SCHEDULED_AT_MILLIS, -1)
                if (scheduledAt >= 0) scheduler.handleSnoozeDue(ruleId, scheduledAt)
            }
            ACTION_TIME_DUE -> {
                val scheduledAt = intent.getLongExtra(EXTRA_SCHEDULED_AT_MILLIS, -1)
                if (scheduledAt >= 0) scheduler.handleTimeDue(ruleId, scheduledAt)
            }
        }
    }

    companion object {
        const val ACTION_DONE = "com.orialthq.ori_beauty.trigger.action.DONE"
        const val ACTION_LATER = "com.orialthq.ori_beauty.trigger.action.LATER"
        const val ACTION_SNOOZE_DUE = "com.orialthq.ori_beauty.trigger.action.SNOOZE_DUE"
        const val ACTION_TIME_DUE = "com.orialthq.ori_beauty.trigger.action.TIME_DUE"
        const val EXTRA_RULE_ID = "trigger_rule_id"
        const val EXTRA_SCHEDULED_AT_MILLIS = "trigger_scheduled_at_millis"
    }
}
