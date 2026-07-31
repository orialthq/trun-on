package com.orialthq.ori_beauty.share

import android.content.Intent

internal object IncomingShareRoutePolicy {
    fun shouldStripData(action: String?): Boolean {
        return action == Intent.ACTION_SEND || action == Intent.ACTION_SEND_MULTIPLE
    }
}
