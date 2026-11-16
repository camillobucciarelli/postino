import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // postino (#38): held for the whole run, so App Nap never slows the sync while the window is hidden.
  private var syncActivity: NSObjectProtocol?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // postino (#239): the window is not visible at launch (MainMenu.xib); started as a login item Postino stays in
    // the menu bar, any other launch shows it as before.
    let atLogin = Self.launchedAsLogInItem()
    LaunchAtLogin.launched(atLogin: atLogin)
    if !atLogin {
      mainFlutterWindow?.makeKeyAndOrderFront(nil)
    }
    syncActivity = ProcessInfo.processInfo.beginActivity(
      options: .userInitiatedAllowingIdleSystemSleep,
      reason: "Postino sincronizza la posta anche con la finestra chiusa")
    super.applicationDidFinishLaunching(notification)
    // The Mac App Store variant (#325, ADR 0021) has no Sparkle: the Store updates it.
    #if !APP_STORE
      CheckForUpdatesMenuItem.install(in: NSApp.mainMenu)
    #endif
    MailMenu.install(in: NSApp.mainMenu)
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

  // The kAEOpenApplication event being handled while the launch finishes carries keyAELaunchedAsLogInItem when the
  // system started the app as a login item (AERegistry.h), as the value of keyAEPropData.
  private static func launchedAsLogInItem() -> Bool {
    guard let event = NSAppleEventManager.shared().currentAppleEvent,
      event.eventClass == kCoreEventClass, event.eventID == kAEOpenApplication
    else { return false }
    return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
      || event.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem) != nil
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
