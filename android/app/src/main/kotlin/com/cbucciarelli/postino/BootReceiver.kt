package com.cbucciarelli.postino

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/// The Notifiche immediate after a reboot or an update of Postino (#214): the service starts again if they are on.
/// `specialUse` may start from BOOT_COMPLETED, also on Android 15 (unlike `dataSync`).
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED && intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        try {
            ListeningService.restore(context)
        } catch (e: Exception) {
            // The periodic check (#212) goes on; the next opening of Postino starts the service.
            Log.w("postino.listening", "restore refused: ${e.javaClass.simpleName}")
        }
    }
}
