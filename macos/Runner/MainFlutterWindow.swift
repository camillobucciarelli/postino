import Cocoa
import FlutterMacOS
import ServiceManagement

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // postino: two panes and the icon sidebar need 900 (breakpoint-list-detail); the window cannot be narrower. 600 is the minimum height.
    self.contentMinSize = NSSize(width: 900, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)
    LaunchAtLogin.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

// postino (#38): avvio al login on "it.postino/launch_at_login", with SMAppService.mainApp (macOS 13+, sandbox
// friendly). isEnabled -> bool, setEnabled(bool). Before macOS 13: never enabled, setEnabled refused.
// ponytail: in this file and not its own, so the Xcode project needs no new source reference.
enum LaunchAtLogin {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "it.postino/launch_at_login", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
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
