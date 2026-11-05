import Cocoa
import Sparkle

// postino (#122): «Cerca aggiornamenti…» in the app menu, right after «About», wired straight to Sparkle
// (which also disables it while a check runs). MainMenu.xib is English only, so the title follows the system.
enum CheckForUpdatesMenuItem {
  static func install(in mainMenu: NSMenu?) {
    guard let appMenu = mainMenu?.items.first?.submenu else { return }
    let italian = Locale.preferredLanguages.first?.hasPrefix("it") ?? false
    let item = NSMenuItem(
      title: italian ? "Cerca aggiornamenti…" : "Check for Updates…",
      action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
      keyEquivalent: "")
    item.target = Updater.controller
    appMenu.insertItem(item, at: min(1, appMenu.items.count))
  }
}
