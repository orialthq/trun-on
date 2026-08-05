package com.orialthq.ori_beauty

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings

/** Opens the deepest portable settings page a regular app may launch. */
internal object LocationPermissionSettingsNavigator {
    fun open(context: Context): Boolean {
        val packageUri = Uri.fromParts("package", context.packageName, null)
        val candidates =
            listOf(
                // Android intentionally does not expose a public intent that lets
                // third-party apps jump directly to one permission group's radio
                // buttons. App details is the deepest portable app-specific page.
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri),
                Intent(Settings.ACTION_APPLICATION_SETTINGS),
                Intent(Settings.ACTION_SETTINGS),
            )

        for (intent in candidates) {
            if (intent.resolveActivity(context.packageManager) == null) {
                continue
            }
            try {
                context.startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
                // Try the next portable settings surface.
            } catch (_: SecurityException) {
                // Some OEMs resolve settings activities that callers cannot open.
            }
        }
        return false
    }
}
