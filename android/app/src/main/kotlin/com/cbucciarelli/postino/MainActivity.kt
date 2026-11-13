package com.cbucciarelli.postino

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/// Shows the app's engine (PostinoEngine), which outlives it while the Notifiche immediate are on (#214).
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Before super: FlutterActivity looks the cached engine up while it attaches.
        val warm = PostinoEngine.isRunning()
        PostinoEngine.ensure(this)
        super.onCreate(savedInstanceState)
        if (warm && savedInstanceState == null) deliver(intent)
    }

    override fun onNewIntent(intent: Intent) {
        // Forwarded to the plugins: a notification's tap reaches flutter_local_notifications.
        super.onNewIntent(intent)
        if (intent.action == ListeningService.OPEN_UNIFIED) PostinoEngine.openUnified()
    }

    override fun getCachedEngineId(): String = PostinoEngine.ID

    /// Destroyed with the Activity as before (closed from the Recents, Back up to Android 11), unless the service keeps it.
    override fun shouldDestroyEngineWithHost(): Boolean = !ListeningService.running

    override fun onDestroy() {
        val destroying = shouldDestroyEngineWithHost()
        super.onDestroy()
        if (destroying) PostinoEngine.forget()
    }

    /// A new Activity on the engine already running is not a cold start: what launched it goes to Dart as it would
    /// while running. flutter_local_notifications reads the launch intent only at a cold start, so a notification's
    /// tap goes to it as a new intent; the fixed notification opens the Posta unificata.
    private fun deliver(intent: Intent) {
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return
        when (intent.action) {
            ListeningService.OPEN_UNIFIED -> PostinoEngine.openUnified()
            // flutter_local_notifications' action for the tap on a notification.
            "SELECT_NOTIFICATION" -> flutterEngine?.activityControlSurface?.onNewIntent(intent)
        }
    }
}
