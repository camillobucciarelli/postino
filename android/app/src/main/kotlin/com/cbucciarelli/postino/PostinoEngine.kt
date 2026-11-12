package com.cbucciarelli.postino

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/// The app's one FlutterEngine (#214), kept in the FlutterEngineCache instead of being owned by MainActivity: while
/// the Notifiche immediate are on, ListeningService keeps it running after the Activity is gone (closed from the
/// Recents), so its SyncEngine goes on with IDLE and the poll. One engine, one sync owner, one IDLE per Account.
/// Without the service the Activity destroys it as before (MainActivity.shouldDestroyEngineWithHost).
object PostinoEngine {
    const val ID = "postino"

    /// Dart's side: lib/core/data/channel_immediate_notifications.dart.
    private const val CHANNEL = "it.postino/immediate_notifications"

    private var channel: MethodChannel? = null

    /// True when the engine was already running: the Activity attaching to it is not a cold start.
    fun isRunning(): Boolean = FlutterEngineCache.getInstance().contains(ID)

    /// The running engine, or a new one running main() (from the Activity, or from the service after a reboot).
    fun ensure(context: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(ID)?.let { return it }
        val app = context.applicationContext
        val engine = FlutterEngine(app)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "start" -> {
                            ListeningService.start(
                                app,
                                ListeningService.Texts(
                                    channel = call.argument<String>("channel")!!,
                                    title = call.argument<String>("title")!!,
                                    text = call.argument<String>("text")!!,
                                ),
                            )
                            result.success(null)
                        }
                        "stop" -> {
                            ListeningService.stop(app)
                            result.success(null)
                        }
                        "requestBatteryExemption" -> result.success(BatteryExemption.request(app))
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    // The class only: Dart reports the failure, and the switch shows what the OS has.
                    result.error("failed", e.javaClass.simpleName, null)
                }
            }
        }
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ID, engine)
        return engine
    }

    /// The fixed notification tapped (#214): Dart opens the Posta unificata.
    fun openUnified() {
        channel?.invokeMethod("openUnified", null)
    }

    /// Called once the Activity destroyed the engine: the next Activity starts a new one.
    fun forget() {
        channel = null
    }
}
