package com.cbucciarelli.postino

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings

/// The esclusione dall'ottimizzazione batteria of the Notifiche immediate (#214): the network in Doze, and the
/// service may start again from the background. The system's own «Consenti» dialog, one tap.
object BatteryExemption {
    /// Asks the system, unless Postino is already excluded.
    // REQUEST_IGNORE_BATTERY_OPTIMIZATIONS is a Play policy matter; Postino is sideloaded (#121).
    @SuppressLint("BatteryLife")
    fun request(context: Context) {
        val power = context.getSystemService(PowerManager::class.java)
        if (power.isIgnoringBatteryOptimizations(context.packageName)) return
        context.startActivity(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${context.packageName}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}
