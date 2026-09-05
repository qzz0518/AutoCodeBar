import AppKit
import SwiftUI

import AutoCodeBarCore

/// 「完整磁盘访问」和「辅助功能」都没法弹窗申请：用户必须自己找到系统设置深处的
/// 那份列表，再把应用加进去。这个引导打开对应面板，在点击处弹出一张卡片，沿弧线飞到
/// 系统设置窗口并带弹性落定，给用户一份可拖拽的应用图标，同时盯着授权探测，
/// 授权后卡片自己确认并退场。两份列表的交互完全同构——都接受把 .app 拖进去、
/// 都有一个开关——所以只有面板链接、探测方式和已授权文案随 `Pane` 变。
///
/// 卡片用 `CGWindowListCopyWindowInfo` 的窗口边界跟随系统设置——不像基于
/// 辅助功能的跟踪，这不需要任何额外授权（一个权限助手反过来先要权限，荒谬）。
@MainActor
final class PrivacyPaneGuide {
  /// 引导指向「隐私与安全性」下的哪一份列表。
  enum Pane {
    case fullDiskAccess
    case accessibility
  }

  static let fullDiskAccess = PrivacyPaneGuide(pane: .fullDiskAccess)
  static let accessibility = PrivacyPaneGuide(pane: .accessibility)

  let pane: Pane

  private var panel: NSPanel?
  private var model: GuideModel
  private var watcher: Task<Void, Never>?
  /// 用户正把行从卡片里拖出来时为真：跟随逻辑不能在拖拽进行中挪动卡片。
  private var followSuspended = false

  private init(pane: Pane) {
    self.pane = pane
    self.model = GuideModel(pane: pane)
  }

  /// 另一个面板的引导。两张卡片停在同一个位置，同时只能有一张。
  private var sibling: PrivacyPaneGuide {
    switch pane {
    case .fullDiskAccess: return Self.accessibility
    case .accessibility: return Self.fullDiskAccess
    }
  }

  func present() {
    sibling.dismiss()
    switch pane {
    case .fullDiskAccess: SystemSettingsLinks.openFullDiskAccess()
    case .accessibility: SystemSettingsLinks.openAccessibility()
    }
    if panel != nil {
      panel?.orderFrontRegardless()
      return
    }

    model = GuideModel(pane: pane)
    model.close = { [weak self] in self?.dismiss() }
    model.dragBegan = { [weak self] in self?.followSuspended = true }
    model.dragEnded = { [weak self] operation, endPoint in
      guard let self else { return }
      self.followSuspended = false
      // 放手就是卡片的退场信号：macOS 紧接着会弹密码表单，浮动卡片没理由压在
      // 它上面。「被任何目标接受」或「落在系统设置窗口上」都算——系统设置即使
      // 接了这个拖放，也不保证回报一个 drag operation。
      let accepted = operation.isEmpty == false
      let overSettings = Self.systemSettingsFrame()?.contains(endPoint) ?? false
      if accepted || overSettings {
        self.dismiss()
      }
    }

    let hosting = NSHostingView(rootView: GuideCard(model: model))
    hosting.frame.size = hosting.fittingSize

    // 无边框且不激活：把图标拖出卡片时不能把焦点从拖放目标（系统设置窗口）抢走。
    let panel = NSPanel(
      contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false // SwiftUI 卡片自己画阴影
    panel.level = .floating
    // 这里不能加 `.transient`：台前调度会把 transient 窗口当作所属应用舞台的一部分，
    // 在系统设置激活的那一刻把它拖出屏幕——而那正是卡片必须待着不动的时刻。
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    // 绝不让 mouse-down 拖动窗口：窗口拖拽会在手势竞争里赢过行的拖拽，
    // 整张卡片会跟着走好几秒才把拖拽项松开。卡片自己会跟随系统设置，手动挪没有意义。
    panel.isMovableByWindowBackground = false
    panel.isMovable = false
    panel.contentView = hosting
    // 卡片假装是系统设置窗口的一条,所以它跟随系统主题——应用自己钉死深色，
    // 不该在浅色的设置窗口上贴一条深色横幅。
    let globals = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
    let systemDark = (globals?["AppleInterfaceStyle"] as? String) == "Dark"
    panel.appearance = NSAppearance(named: systemDark ? .darkAqua : .aqua)
    self.panel = panel

    // 生在光标下——卡片看得见地从用户刚按下的按钮那里出来，然后飞到活儿所在的地方。
    let click = NSEvent.mouseLocation
    let size = panel.frame.size
    panel.setFrameOrigin(NSPoint(x: click.x - size.width / 2, y: click.y - size.height / 2))
    panel.alphaValue = 0
    panel.orderFrontRegardless()

    Task { [weak self] in await self?.launchFlight() }
  }

  func dismiss() {
    watcher?.cancel()
    watcher = nil
    panel?.orderOut(nil)
    panel = nil
  }

  // MARK: - 入场飞行

  /// 在点击处弹出，等系统设置窗口自己的启动动画结束，然后飞过去落定。
  private func launchFlight() async {
    guard let panel else { return }

    model.appeared = true
    await NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.16
      panel.animator().alphaValue = 1
    }

    // 冷启动的系统设置会有入场动画；朝一个移动的目标飞会落错地方。
    // 相隔 100ms 的两次相同观测算稳定；三秒都没等到就用兜底位置。
    var previous: NSRect?
    var target: NSPoint?
    for _ in 0..<30 {
      try? await Task.sleep(for: .milliseconds(100))
      guard self.panel != nil else { return }
      guard let frame = Self.systemSettingsFrame() else { continue }
      if let seen = previous,
         abs(seen.origin.x - frame.origin.x) < 1,
         abs(seen.origin.y - frame.origin.y) < 1,
         abs(seen.width - frame.width) < 1 {
        target = perch(beside: frame, size: panel.frame.size)
        break
      }
      previous = frame
    }

    await fly(to: target ?? fallbackPerch(size: panel.frame.size))
    startWatcher()
  }

  /// 顶点固定 160pt 的二次贝塞尔弧，进度由欠阻尼弹簧驱动——卡片会稍微冲过
  /// 落点再退回来，而不是像货车一样减速停下。
  private func fly(to end: NSPoint) async {
    guard let panel else { return }
    let start = panel.frame.origin
    let dx = end.x - start.x, dy = end.y - start.y
    guard (dx * dx + dy * dy).squareRoot() > 40 else {
      panel.setFrameOrigin(end)
      return
    }

    let control = NSPoint(x: (start.x + end.x) / 2, y: max(start.y, end.y) + 160)
    let omega = 11.0, zeta = 0.55
    let omegaD = omega * (1 - zeta * zeta).squareRoot()
    let duration = 0.85
    let began = CACurrentMediaTime()

    while let panel = self.panel {
      let elapsed = CACurrentMediaTime() - began
      if elapsed >= duration { break }
      let decay = exp(-zeta * omega * elapsed)
      let t = 1 - decay * (cos(omegaD * elapsed) + zeta * omega / omegaD * sin(omegaD * elapsed))
      panel.setFrameOrigin(Self.point(on: (start, control, end), at: t))
      try? await Task.sleep(for: .milliseconds(8))
    }
    self.panel?.setFrameOrigin(end)
  }

  /// `t` ∈ [0, 1] 上的贝塞尔位置；超过 1 时卡片沿出射切线继续（限 18pt），
  /// 好让弹簧的过冲有地方去，再被拉回来。
  private static func point(
    on curve: (s: NSPoint, c: NSPoint, e: NSPoint), at t: Double
  ) -> NSPoint {
    if t <= 1 {
      let u = 1 - t
      return NSPoint(
        x: u * u * curve.s.x + 2 * u * t * curve.c.x + t * t * curve.e.x,
        y: u * u * curve.s.y + 2 * u * t * curve.c.y + t * t * curve.e.y
      )
    }
    let dx = 2 * (curve.e.x - curve.c.x), dy = 2 * (curve.e.y - curve.c.y)
    let length = max((dx * dx + dy * dy).squareRoot(), 0.001)
    let over = min((t - 1) * length, 18)
    return NSPoint(x: curve.e.x + dx / length * over, y: curve.e.y + dy / length * over)
  }

  // MARK: - 跟随

  private func startWatcher() {
    watcher?.cancel()
    watcher = Task { [weak self] in
      // 150ms 能把卡片粘在被拖动的设置窗口上；更慢的节拍会看到明显的追赶顿挫。
      // TCC 探测走更慢的拍子，授权不需要 7Hz。
      var beat = 0
      while let self, self.panel != nil, Task.isCancelled == false {
        self.tick(runProbe: beat % 5 == 0)
        beat += 1
        try? await Task.sleep(for: .milliseconds(150))
      }
    }
  }

  private func tick(runProbe: Bool) {
    if followSuspended == false {
      glideAlongsideSettings()
    }
    guard runProbe, model.granted == false else { return }
    if isGranted {
      model.granted = true
      // 长到足够让绿勾被看见，短到用户切回应用时卡片已经走了。
      // macOS 也可能在这里重启我们——引导进度键会活下来。
      Task { [weak self] in
        try? await Task.sleep(for: .seconds(1.6))
        self?.dismiss()
      }
    }
  }

  /// 面板对应的授权探测。两者都是同步、无副作用的查询。
  private var isGranted: Bool {
    switch pane {
    case .fullDiskAccess: return PermissionProbe.fullDiskAccess() == .granted
    case .accessibility: return PermissionProbe.accessibility()
    }
  }

  /// 落定后与系统设置保持站位；用户拖那个窗口时应该感觉卡片是贴在上面的。
  private func glideAlongsideSettings() {
    guard let panel, let settings = Self.systemSettingsFrame() else { return }
    let target = perch(beside: settings, size: panel.frame.size)
    guard abs(panel.frame.origin.x - target.x) > 1 || abs(panel.frame.origin.y - target.y) > 1 else {
      return
    }
    // 略长于 150ms 的轮询，让连续的缓动跳跃融成一条连贯的追随，而不是离散步进。
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.18
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().setFrame(NSRect(origin: target, size: panel.frame.size), display: true)
    }
  }

  /// 系统设置窗口**内部**的右下角，像一张盖在权限列表上的浮条——离窗口右边和
  /// 底边各 18pt。面板比可见卡片每边大 `GuideCard.shadowPad`，故有偏移运算。
  private func perch(beside settings: NSRect, size: NSSize) -> NSPoint {
    let screen = NSScreen.screens.first { $0.frame.intersects(settings) } ?? NSScreen.main
    let visible = screen?.visibleFrame ?? settings
    let inset: CGFloat = 18
    var x = settings.maxX - inset + GuideCard.shadowPad - size.width
    var y = settings.minY + inset - GuideCard.shadowPad
    x = max(visible.minX - GuideCard.shadowPad, min(x, visible.maxX + GuideCard.shadowPad - size.width))
    y = max(visible.minY - GuideCard.shadowPad, min(y, visible.maxY + GuideCard.shadowPad - size.height))
    return NSPoint(x: x, y: y)
  }

  private func fallbackPerch(size: NSSize) -> NSPoint {
    guard let visible = NSScreen.main?.visibleFrame else { return .zero }
    return NSPoint(
      x: visible.maxX + GuideCard.shadowPad - size.width - 24,
      y: visible.minY - GuideCard.shadowPad + 24
    )
  }

  /// AppKit 坐标下的系统设置窗口。按 PID 而不是所有者名匹配，本地化改不坏它；
  /// 窗口边界和所有者 PID 都不需要任何 TCC 授权就能读。
  private static func systemSettingsFrame() -> NSRect? {
    guard let app = NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.apple.systempreferences"
    ).first else { return nil }
    guard let windows = CGWindowListCopyWindowInfo(
      [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
    ) as? [[String: Any]] else { return nil }

    // 取最大的窗口，而不是最前面的：拖放之后系统设置弹出的管理员密码表单
    // 也是同一进程的 layer-0 窗口，按前后顺序会锁到它上面——实测卡片会跳上去
    // 挡住那张表单。
    var best: NSRect?
    for entry in windows {
      guard let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
            pid == app.processIdentifier,
            (entry[kCGWindowLayer as String] as? Int) == 0,
            let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat],
            let x = bounds["X"], let y = bounds["Y"],
            let width = bounds["Width"], let height = bounds["Height"],
            width > 200, height > 200
      else { continue }
      // CG 的矩形从主显示器左上角向下长；AppKit 从左下角向上长。
      let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
      let rect = NSRect(x: x, y: primaryHeight - y - height, width: width, height: height)
      if rect.width * rect.height > (best.map { $0.width * $0.height } ?? 0) {
        best = rect
      }
    }
    return best
  }
}

// MARK: - 卡片

@MainActor
private final class GuideModel: ObservableObject {
  /// 卡片据此选已授权文案；指令文案两个面板相同。
  let pane: PrivacyPaneGuide.Pane
  @Published var granted = false
  @Published var appeared = false
  var close: () -> Void = {}
  var dragBegan: () -> Void = {}
  var dragEnded: (NSDragOperation, NSPoint) -> Void = { _, _ in }

  init(pane: PrivacyPaneGuide.Pane) {
    self.pane = pane
  }
}

/// 覆在行上的 AppKit 拖拽源：鼠标移动几个点就开始文件拖拽（SwiftUI 的 `.onDrag`
/// 有一段能感觉到的按住延迟），并且——这是 SwiftUI 根本做不到的——回报拖拽在
/// 哪里结束、有没有被接受，卡片正是靠这个给密码表单让路。
private struct AppDragHandle: NSViewRepresentable {
  let began: () -> Void
  let ended: (NSDragOperation, NSPoint) -> Void

  func makeNSView(context: Context) -> DragView {
    let view = DragView()
    view.began = began
    view.ended = ended
    return view
  }

  func updateNSView(_ view: DragView, context: Context) {}

  final class DragView: NSView, NSDraggingSource {
    var began: () -> Void = {}
    var ended: (NSDragOperation, NSPoint) -> Void = { _, _ in }
    private var pressOrigin: NSPoint?

    // 这个面板永远不会成为 key 窗口；拖拽必须在第一次点击就能用。
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
      pressOrigin = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
      guard let origin = pressOrigin else { return }
      let dx = event.locationInWindow.x - origin.x
      let dy = event.locationInWindow.y - origin.y
      guard dx * dx + dy * dy > 9 else { return }
      pressOrigin = nil

      let item = NSDraggingItem(pasteboardWriter: Bundle.main.bundleURL as NSURL)
      let icon = NSApp.applicationIconImage ?? NSImage()
      let grab = convert(event.locationInWindow, from: nil)
      item.setDraggingFrame(
        NSRect(x: grab.x - 20, y: grab.y - 20, width: 40, height: 40),
        contents: icon
      )
      began()
      beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(
      _ session: NSDraggingSession,
      sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
      context == .outsideApplication ? [.copy, .generic, .link] : []
    }

    nonisolated func draggingSession(
      _ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation
    ) {
      MainActor.assumeIsolated {
        ended(operation, screenPoint)
      }
    }
  }
}

/// 一条用系统设置自身视觉语言（系统色，不是应用主题）画出来的横幅：
/// 一句指令，加上一个可拖拽的行——它就是用户即将在上方权限列表里创建的那一行。
private struct GuideCard: View {
  /// 卡片四周的透明边距，免得画出的阴影被无边框面板裁掉。定位运算已计入它。
  static let shadowPad: CGFloat = 26

  @ObservedObject var model: GuideModel

  private static var instructionMarkdown: String {
    L10n.text("把 **AutoCodeBar** 拖进上方列表，然后打开它的开关")
  }

  private var instruction: AttributedString {
    (try? AttributedString(markdown: Self.instructionMarkdown))
      ?? AttributedString(Self.instructionMarkdown)
  }

  private var grantedText: String {
    switch model.pane {
    case .fullDiskAccess:
      return L10n.text("已授权 — macOS 可能会要求重新打开 AutoCodeBar。")
    case .accessibility:
      return L10n.text("已授权，一键填入已可用。")
    }
  }

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Button { model.close() } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 22, height: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 11) {
        if model.granted {
          HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(Color(nsColor: .systemGreen))
            Text(grantedText)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.primary)
              .lineLimit(1)
          }
        } else {
          HStack(spacing: 8) {
            Image(systemName: "arrow.up")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(Color(nsColor: .systemBlue))
            Text(instruction)
              .font(.system(size: 13))
              .foregroundStyle(.primary)
              .lineLimit(1)
          }
        }

        // 可拖拽的载荷，打扮成它落地后会变成的那一行设置列表项。
        HStack(spacing: 9) {
          Image(nsImage: NSApp.applicationIconImage ?? NSImage())
            .resizable()
            .frame(width: 24, height: 24)
          Text(verbatim: "AutoCodeBar")
            .font(.system(size: 13))
            .foregroundStyle(.primary)
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
          Color.primary.opacity(0.065),
          in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(AppDragHandle(began: model.dragBegan, ended: model.dragEnded))
      }
    }
    .padding(.leading, 10)
    .padding(.trailing, 18)
    .padding(.vertical, 14)
    .frame(width: 560)
    .background(
      Color(nsColor: .windowBackgroundColor),
      in: RoundedRectangle(cornerRadius: 24, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: Theme.Stroke.hairline)
    )
    .shadow(color: .black.opacity(0.28), radius: 18, y: 6)
    .padding(Self.shadowPad)
    .scaleEffect(model.appeared ? 1 : 0.55, anchor: .center)
    .opacity(model.appeared ? 1 : 0)
    .animation(.spring(response: 0.38, dampingFraction: 0.68), value: model.appeared)
    .animation(.easeOut(duration: 0.2), value: model.granted)
  }
}

#if DEBUG
extension PrivacyPaneGuide {
  /// 离屏快照用：不开面板、不跟随系统设置，只把卡片本身交出来。
  @MainActor
  static func debugCard(pane: Pane, granted: Bool) -> some View {
    let model = GuideModel(pane: pane)
    model.granted = granted
    model.appeared = true
    return GuideCard(model: model)
  }
}
#endif
