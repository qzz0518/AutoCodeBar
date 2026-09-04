import AppKit
import SwiftUI

import AutoCodeBarCore

/// 非激活的浮动面板，用来把 `QuickFillCard` 贴在聚焦的输入框旁边。
///
/// 关键是「不抢焦点」：点面板的那一刻光标必须还在目标输入框所在的窗口里，
/// 否则 AX 把焦点设回去之前就已经换了前台应用。
@MainActor
final class QuickFillPanel {
  private var panel: NSPanel?
  private var hosting: FirstMouseHostingView<QuickFillCard>?

  var isVisible: Bool {
    panel?.isVisible ?? false
  }

  /// 把卡片摆到 `anchor`（输入框的 AppKit 全局矩形）下方；下方放不下就翻到上方。
  func show(
    event: CodeEvent,
    pressesReturn: Bool,
    anchor: NSRect,
    onFill: @escaping () -> Void,
    onDismiss: @escaping () -> Void
  ) {
    // `pressesReturn` 不出现在卡片上——是否回车由控制器在键入时决定，
    // 这里只是把会话状态完整地交给展示层。
    _ = pressesReturn

    let card = QuickFillCard(event: event, onFill: onFill, onDismiss: onDismiss)
    let host = ensureHost(card)
    host.rootView = card
    host.layoutSubtreeIfNeeded()

    let size = host.fittingSize
    host.frame = NSRect(origin: .zero, size: size)
    guard let panel else {
      return
    }
    panel.appearance = NSAppearance(named: Self.systemPrefersDark ? .darkAqua : .aqua)

    let frame = NSRect(origin: origin(for: anchor, panelSize: size), size: size)
    let wasVisible = panel.isVisible
    if wasVisible,
       abs(panel.frame.origin.x - frame.origin.x) < 1,
       abs(panel.frame.origin.y - frame.origin.y) < 1,
       abs(panel.frame.width - frame.width) < 1,
       abs(panel.frame.height - frame.height) < 1 {
      return
    }
    panel.setFrame(frame, display: true)
    panel.invalidateShadow()

    guard !wasVisible else {
      return
    }
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    panel.alphaValue = reduceMotion ? 1 : 0
    panel.orderFrontRegardless()
    guard !reduceMotion else {
      return
    }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.15
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().alphaValue = 1
    }
  }

  /// 幂等。
  func hide() {
    panel?.orderOut(nil)
  }

  // MARK: - 面板

  private func ensureHost(_ card: QuickFillCard) -> FirstMouseHostingView<QuickFillCard> {
    if let hosting {
      return hosting
    }
    let host = FirstMouseHostingView(rootView: card)
    host.frame = NSRect(origin: .zero, size: host.fittingSize)

    let panel = NSPanel(
      contentRect: host.frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = .floating
    // 不加 `.transient`：台前调度会把 transient 面板当成本应用舞台的一部分，
    // 在别的应用激活时把它拖走——而那正是卡片必须待着不动的时刻。
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.hidesOnDeactivate = false
    panel.becomesKeyOnlyIfNeeded = true
    panel.isMovable = false
    panel.isMovableByWindowBackground = false
    panel.isOpaque = false
    panel.backgroundColor = .clear
    // 阴影交给窗口：按内容透明形状生成，圆角外不会留下被裁掉的硬边。
    panel.hasShadow = true
    panel.contentView = host

    self.panel = panel
    hosting = host
    return host
  }

  /// 卡片贴着输入框下沿，左边对齐；下方超出屏幕就翻到上方，x 夹在屏幕可见区内。
  /// 面板矩形就是卡片矩形，没有额外的透明边距。
  private func origin(for anchor: NSRect, panelSize: NSSize) -> NSPoint {
    let card = panelSize
    let center = NSPoint(x: anchor.midX, y: anchor.midY)
    let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
    let visible = screen?.visibleFrame ?? anchor

    var cardOrigin = NSPoint(x: anchor.minX, y: anchor.minY - 6 - card.height)
    if cardOrigin.y < visible.minY {
      cardOrigin.y = anchor.maxY + 6
    }
    let maxX = max(visible.minX, visible.maxX - card.width)
    cardOrigin.x = max(visible.minX, min(cardOrigin.x, maxX))
    return cardOrigin
  }

  /// 面板贴在别人的窗口旁边，跟随系统外观，而不是应用自己的偏好。
  private static var systemPrefersDark: Bool {
    let globals = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
    return (globals?["AppleInterfaceStyle"] as? String) == "Dark"
  }
}

/// 非 key 窗口里的第一次点击必须直接落到按钮上，不能先被拿去激活窗口。
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }
}
