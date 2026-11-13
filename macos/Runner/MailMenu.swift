import Cocoa
import FlutterMacOS

// postino (#251): the «Posta» menu, before «Window», with «Aggiorna» (Cmd+R). Choosing it calls `refresh` on the
// channel "it.postino/menu": the Dart side runs the same «Aggiorna» as the list's bar. MainMenu.xib is English only,
// so the titles follow the system, like «Cerca aggiornamenti…».
enum MailMenu {
  private static var channel: FlutterMethodChannel?
  private static let target = Target()

  static func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "it.postino/menu", binaryMessenger: messenger)
  }

  static func install(in mainMenu: NSMenu?) {
    guard let mainMenu else { return }
    let italian = Locale.preferredLanguages.first?.hasPrefix("it") ?? false
    let menu = NSMenu(title: italian ? "Posta" : "Mail")
    let item = NSMenuItem(
      title: italian ? "Aggiorna" : "Refresh", action: #selector(Target.refresh(_:)), keyEquivalent: "r")
    item.target = target
    menu.addItem(item)
    let top = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
    top.submenu = menu
    let window = mainMenu.items.firstIndex { $0.submenu == NSApp.windowsMenu } ?? mainMenu.items.count
    mainMenu.insertItem(top, at: window)
  }

  private final class Target: NSObject {
    @objc func refresh(_ sender: Any?) {
      // true for Cmd+R: Flutter, which gets the key first, left it (a text field), so Dart ignores it.
      MailMenu.channel?.invokeMethod("refresh", arguments: NSApp.currentEvent?.type == .keyDown)
    }
  }
}
