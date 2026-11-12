import Cocoa
import FlutterMacOS

// postino (#211): "open" on "it.postino/notification_settings" opens Postino's page in System Settings › Notifiche,
// where a refused permission is given back (the OS asks only once).
enum NotificationSettings {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "it.postino/notification_settings", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "open" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let id = Bundle.main.bundleIdentifier ?? ""
      let page = "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)"
      if let url = URL(string: page) { NSWorkspace.shared.open(url) }
      result(nil)
    }
  }
}
