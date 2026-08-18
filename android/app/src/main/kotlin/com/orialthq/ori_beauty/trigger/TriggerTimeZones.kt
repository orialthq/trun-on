package com.orialthq.ori_beauty.trigger

import java.util.TimeZone

internal object TriggerTimeZones {
    fun requireKnown(id: String?) {
        if (id == null) return
        val resolved = TimeZone.getTimeZone(id)
        require(resolved.id == id || id == "GMT") { "Unknown time zone id: $id" }
    }

    fun resolve(id: String?): TimeZone {
        requireKnown(id)
        return if (id == null) TimeZone.getDefault() else TimeZone.getTimeZone(id)
    }
}
