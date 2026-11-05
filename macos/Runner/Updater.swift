import FlutterMacOS
import Sparkle

// postino (#122): aggiornamenti with Sparkle 2. Feed, public EdDSA key and sandbox installer are in Info.plist;
// automatic checks follow Sparkle's defaults. The channel "it.postino/updater" answers checkForUpdates, which
// shows Sparkle's own window (it also says when there is nothing new).
enum Updater {
  // Created (and started) at the first use, the channel's registration at launch; held for the whole run.
  static let controller = SPUStandardUpdaterController(
    startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

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
