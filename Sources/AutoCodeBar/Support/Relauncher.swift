import AppKit
import Foundation

/// 重新启动应用（授权后 TCC 需要新进程才能生效）。
enum Relauncher {
  static func relaunch() {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true
    NSWorkspace.shared.openApplication(
      at: Bundle.main.bundleURL,
      configuration: configuration
    ) { _, _ in
      DispatchQueue.main.async {
        NSApp.terminate(nil)
      }
    }
  }
}
