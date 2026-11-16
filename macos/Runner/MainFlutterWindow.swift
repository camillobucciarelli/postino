import Cocoa
import FlutterMacOS

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
    #if !APP_STORE  // #325: no Sparkle in the Mac App Store variant (ADR 0021)
      Updater.register(with: flutterViewController.engine.binaryMessenger)
    #endif
    MailMenu.register(with: flutterViewController.engine.binaryMessenger)
    // postino (ADR 0019): "it.postino/screen_guard" protect(bool). sharingType is a legacy API Apple advises against
    // for stopping captures: set anyway, never relied on.
    let guardChannel = FlutterMethodChannel(
      name: "it.postino/screen_guard", binaryMessenger: flutterViewController.engine.binaryMessenger)
    guardChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "protect" else { return result(FlutterMethodNotImplemented) }
      self?.sharingType = (call.arguments as? Bool) == true ? .none : .readOnly
      result(false)
    }

    super.awakeFromNib()
  }
}
