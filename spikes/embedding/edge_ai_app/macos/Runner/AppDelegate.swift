import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Spike #103: senza, App Nap rallenta l'embedding quando la finestra è in background (README flutter_edge_ai_litertlm).
  private let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "misure embedding")

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
