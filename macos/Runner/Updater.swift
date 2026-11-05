import FlutterMacOS
import Sparkle

// postino (#122): aggiornamenti with Sparkle 2. Feed, public EdDSA key and sandbox installer are in Info.plist;
// automatic checks follow Sparkle's defaults. The channel "it.postino/updater" answers checkForUpdates, which
// shows Sparkle's own window (it also says when there is nothing new).
enum Updater {
  // Created (and started) at the first use, the channel's registration at launch; held for the whole run.
  // A Debug build (CFBundleVersion 1) never starts it: it would offer every release in place of itself.
  #if DEBUG
    private static let starts = false
  #else
    private static let starts = true
  #endif
  static let controller = SPUStandardUpdaterController(
    startingUpdater: starts, updaterDelegate: nil, userDriverDelegate: nil)

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "it.postino/updater", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "checkForUpdates":
        controller.checkForUpdates(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
