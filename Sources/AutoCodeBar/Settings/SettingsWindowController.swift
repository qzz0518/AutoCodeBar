import AppKit
import SwiftUI

/// 自绘的设置窗口。
///
/// SwiftUI 的 `Settings` 场景不接受 `.windowStyle(.hiddenTitleBar)`，它总会画一条
/// 系统标题栏；左导航列要从窗口顶部铺到底部、交通灯直接叠在上面，只能自己开窗。
@MainActor
final class SettingsWindowController {
  static let shared = SettingsWindowController()

  private weak var state: AppState?
  private var window: NSWindow?

  var isVisible: Bool {
    window?.isVisible ?? false
  }

  /// 由 `AppState.bootstrap()` 调用一次。
  func configure(state: AppState) {
    self.state = state
  }

  /// `tab` 只在窗口第一次建出来时生效；已经开着的窗口保持用户停在的那一页。
  func show(tab: SettingsTab = .general) {
    guard let state else {
      return
    }

    if let window {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let controller = NSHostingController(rootView: SettingsView(state: state, initialTab: tab))
    let window = NSWindow(contentViewController: controller)
    window.title = ""
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.styleMask = [.titled, .closable, .fullSizeContentView]
    window.isMovableByWindowBackground = true
    window.isReleasedWhenClosed = false
    window.setContentSize(NSSize(width: 800, height: 580))
    window.center()
    self.window = window

    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func close() {
    window?.close()
  }
}
