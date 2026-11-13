package com.cbucciarelli.postino

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/// The Notifiche immediate (#214): a `specialUse` foreground service (no daily limit, unlike `dataSync` on Android
/// 15) whose only job is to keep the process and the app's engine (PostinoEngine) alive with Postino closed. The sync
/// itself is the app's SyncEngine: IDLE for Gmail and IMAP, the 60 s poll for Microsoft and while IDLE is down.
/// Its fixed notification, «Postino in ascolto», opens the Posta unificata.
class ListeningService : Service() {
    /// The texts of the fixed notification, from Dart's i18n; kept for a start after a reboot.
    data class Texts(val channel: String, val title: String, val text: String)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val texts = saved(this)
        if (texts == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            val notification = notification(this, texts)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // A restart the system does not allow from the background (Android 12+, no battery exemption): the
            // periodic check (#212) goes on, the next opening of Postino starts the service again.
            Log.w(TAG, "start refused: ${e.javaClass.simpleName}")
            stopSelf()
            return START_NOT_STICKY
        }
        running = true
        PostinoEngine.ensure(this)
        // Killed for memory: the system starts it again.
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    companion object {
        private const val TAG = "postino.listening"
        private const val CHANNEL_ID = "postino.listening"
        private const val NOTIFICATION_ID = 214
        private const val PREFS = "postino.listening"
        const val OPEN_UNIFIED = "com.cbucciarelli.postino.OPEN_UNIFIED"

        /// True while the service is in the foreground in this process.
        @Volatile
        var running = false
            private set

        /// Turns the Notifiche immediate on: remembered for the reboot, started, or its notification refreshed.
        fun start(context: Context, texts: Texts) {
            prefs(context).edit()
                .putBoolean("enabled", true)
                .putString("channel", texts.channel)
                .putString("title", texts.title)
                .putString("text", texts.text)
                .apply()
            if (running) {
                // Already in the foreground: no new start, which the background would not allow.
                context.getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification(context, texts))
                return
            }
            launch(context)
        }

        fun stop(context: Context) {
            prefs(context).edit().putBoolean("enabled", false).apply()
            context.stopService(Intent(context, ListeningService::class.java))
        }

        /// After a reboot or an update (BootReceiver): started again when on.
        fun restore(context: Context) {
            if (saved(context) != null) launch(context)
        }

        private fun launch(context: Context) {
            val intent = Intent(context, ListeningService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        /// The texts while the Notifiche immediate are on; null when off.
        private fun saved(context: Context): Texts? {
            val p = prefs(context)
            if (!p.getBoolean("enabled", false)) return null
            return Texts(
                channel = p.getString("channel", null) ?: return null,
                title = p.getString("title", null) ?: return null,
                text = p.getString("text", null) ?: return null,
            )
        }

        @Suppress("DEPRECATION")
        private fun notification(context: Context, texts: Texts): Notification {
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).setAction(OPEN_UNIFIED).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // LOW, not MIN: a foreground service's MIN notification makes the system add one of its own
                // (NotificationManager.IMPORTANCE_MIN). Silent, no badge, no status bar icon where the user hides
                // the silent ones.
                val channel = NotificationChannel(CHANNEL_ID, texts.channel, NotificationManager.IMPORTANCE_LOW)
                channel.setShowBadge(false)
                context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
                Notification.Builder(context, CHANNEL_ID)
            } else {
                Notification.Builder(context).setPriority(Notification.PRIORITY_MIN)
            }
            return builder
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(texts.title)
                .setContentText(texts.text)
                .setContentIntent(open)
                .setOngoing(true)
                .setShowWhen(false)
                .setCategory(Notification.CATEGORY_SERVICE)
                .build()
        }
    }
}
