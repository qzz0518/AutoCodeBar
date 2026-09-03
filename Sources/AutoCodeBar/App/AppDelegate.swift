import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let updater: AppUpdater
  let state: AppState

  override init() {
    let updater = AppUpdater()
    self.updater = updater
    self.state = AppState(updater: updater)
    super.init()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    #if DEBUG
    if DebugSnapshot.runIfRequested(state: state) {
      return
    }
    #endif
    state.bootstrap()
  }

  /// 菜单栏应用：关闭欢迎窗或设置窗不应退出。
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }
}
