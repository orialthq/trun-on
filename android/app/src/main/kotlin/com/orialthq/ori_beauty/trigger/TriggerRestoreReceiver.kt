package com.orialthq.ori_beauty.trigger

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class TriggerRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        if (intent.action !in SUPPORTED_ACTIONS) return
        val pendingResult = goAsync()
        NativeTriggerScheduler(context).restore { pendingResult.finish() }
    }

    companion object {
        private val SUPPORTED_ACTIONS =
            setOf(
                Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_MY_PACKAGE_REPLACED,
            )
    }
}
