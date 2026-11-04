import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // postino (#38): held for the whole run, so App Nap never slows the sync while the window is hidden.
  private var syncActivity: NSObjectProtocol?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    syncActivity = ProcessInfo.processInfo.beginActivity(
      options: .userInitiatedAllowingIdleSystemSleep,
      reason: "Postino sincronizza la posta anche con la finestra chiusa")
    super.applicationDidFinishLaunching(notification)
  }

  // postino (#38): closing the window leaves Postino in the menu bar; «Esci» (or Cmd+Q) ends it.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  // postino (#38): a click on the Dock icon brings back the window hidden in the menu bar.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      mainFlutterWindow?.makeKeyAndOrderFront(nil)
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
