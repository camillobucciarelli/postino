package com.cbucciarelli.postino

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings

/// The esclusione dall'ottimizzazione batteria of the Notifiche immediate (#214): the network in Doze, and the
/// service may start again from the background. The APK from the site (#121) opens the system's own «Consenti»
/// dialog, one tap; the Google Play variant (#345), whose manifest drops the permission of that dialog, opens the
/// system's list of the battery optimization, where the user excludes Postino by hand.
object BatteryExemption {
    /// Asks the system, unless Postino is already excluded.
    // REQUEST_IGNORE_BATTERY_OPTIMIZATIONS is a Play policy matter: only the `site` flavor holds it (ADR 0023).
    @SuppressLint("BatteryLife")
    fun request(context: Context) {
        val power = context.getSystemService(PowerManager::class.java)
        if (power.isIgnoringBatteryOptimizations(context.packageName)) return
        // A normal permission: held exactly when the merged manifest declares it, so the flavor decides here too.
        val dialog = context.checkSelfPermission(Manifest.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS) ==
            PackageManager.PERMISSION_GRANTED
        val intent = if (dialog) {
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${context.packageName}"))
        } else {
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        }
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
