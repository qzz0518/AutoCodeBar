import AppKit
import SwiftUI

import AutoCodeBarCore

/// 引导窗口。面板型应用无法在启动时通过 SwiftUI 场景可靠地开窗，改用 AppKit。
@MainActor
final class OnboardingWindowController {
  private var window: NSWindow?

  var isVisible: Bool {
    window?.isVisible ?? false
  }

  func show(state: AppState) {
    if let window {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let controller = NSHostingController(rootView: OnboardingFlow(state: state))
    let window = NSWindow(contentViewController: controller)
    window.title = L10n.text("设置 AutoCodeBar")
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.styleMask = [.titled, .closable, .fullSizeContentView]
    window.isReleasedWhenClosed = false
    window.setContentSize(NSSize(width: 920, height: 600))
    // 授权完整磁盘访问会把用户带到另一个 Space；引导窗必须跟过去。
    window.collectionBehavior = [.canJoinAllSpaces]
    window.center()
    self.window = window

    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func close() {
    window?.close()
  }
}
