import FlutterMacOS
import ServiceManagement

// postino (#38): avvio al login on "it.postino/launch_at_login", with SMAppService.mainApp (macOS 13+, sandbox
// friendly). isEnabled -> bool, setEnabled(bool). Before macOS 13: never enabled, setEnabled refused.
// launchedAtLogin -> bool (#239): whether this run was started as a login item, answered once the launch finished.
enum LaunchAtLogin {
  private static var atLogin: Bool?
  private static var waiting: [FlutterResult] = []

  // Called by the AppDelegate when the launch finishes; answers the asks that came before.
  static func launched(atLogin value: Bool) {
    atLogin = value
    waiting.forEach { $0(value) }
    waiting.removeAll()
  }

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "it.postino/launch_at_login", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "launchedAtLogin" {
        if let atLogin { result(atLogin) } else { waiting.append(result) }
        return
      }
      guard #available(macOS 13.0, *) else {
        result(call.method == "isEnabled"
          ? false
          : FlutterError(code: "unsupported", message: "Avvio al login da macOS 13", details: nil))
        return
      }
      let service = SMAppService.mainApp
      switch call.method {
      case "isEnabled":
        result(service.status == .enabled)
      case "setEnabled":
        guard let enabled = call.arguments as? Bool else {
          result(FlutterError(code: "bad_args", message: "setEnabled takes a bool", details: nil))
          return
        }
        do {
          if enabled {
            try service.register()
            // Turned off earlier in System Settings › Login Items: only the user can turn it on there.
            if service.status == .requiresApproval {
              SMAppService.openSystemSettingsLoginItems()
              result(FlutterError(code: "requires_approval", message: "Login Items", details: nil))
              return
            }
          } else if service.status != .notRegistered {
            try service.unregister()
          }
          result(nil)
        } catch {
          result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
