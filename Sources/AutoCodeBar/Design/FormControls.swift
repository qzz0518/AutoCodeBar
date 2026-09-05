import AppKit
import SwiftUI

/// 设置窗口里所有输入、选择、动作控件共用的一套尺寸。
///
/// 宽度归布局管，高度归这里管：一行里挨着的开关、药丸和按钮只要高度不一致，
/// 整页就会看起来像几批人分别做的。
enum SettingsControlMetrics {
  static let height: CGFloat = 28
  /// 短文案（「打开」「重试」）不至于缩成一小块；长文案照内容撑开，不截断。
  static let minWidth: CGFloat = 72
  static let font = Font.system(size: 12.5, weight: .medium)
  static let radius: CGFloat = 8
  static let inset: CGFloat = 10
}

// MARK: - 焦点环

private struct SettingsKeyboardNavigationKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  /// 最近一次输入来自键盘。焦点环据此显隐。
  var settingsKeyboardNavigation: Bool {
    get { self[SettingsKeyboardNavigationKey.self] }
    set { self[SettingsKeyboardNavigationKey.self] = newValue }
  }
}

/// popover 收起后焦点会留在触发它的按钮上。焦点环只在键盘操作时画出来，
/// 否则每点一次按钮都要多出一圈框，而那圈框对鼠标用户毫无信息量。
private final class SettingsInputMethod: ObservableObject {
  @Published var keyboard = false

  private var monitor: Any?

  func start() {
    guard monitor == nil else {
      return
    }
    monitor = NSEvent.addLocalMonitorForEvents(
      matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
    ) { [weak self] event in
      let keyboard = event.type == .keyDown
      if self?.keyboard != keyboard {
        self?.keyboard = keyboard
      }
      return event
    }
  }

  func stop() {
    if let monitor {
      NSEvent.removeMonitor(monitor)
    }
    monitor = nil
    keyboard = false
  }

  /// 视图没走 `onDisappear` 就被丢掉时的兜底：监视器留在全局队列里不会自己消失。
  deinit {
    if let monitor {
      NSEvent.removeMonitor(monitor)
    }
  }
}

/// 挂在设置窗口根上：整棵树共享同一个「刚才是不是在用键盘」的判断。
struct SettingsFocusScope: ViewModifier {
  @StateObject private var input = SettingsInputMethod()

  func body(content: Content) -> some View {
    content
      .environment(\.settingsKeyboardNavigation, input.keyboard)
      .onAppear { input.start() }
      .onDisappear { input.stop() }
  }
}

struct SettingsFocusRing: ViewModifier {
  let focused: Bool
  var radius = SettingsControlMetrics.radius

  @Environment(\.settingsKeyboardNavigation) private var keyboard

  func body(content: Content) -> some View {
    content.overlay {
      RoundedRectangle(cornerRadius: radius, style: .continuous)
        .strokeBorder(focused && keyboard ? Theme.ink : .clear, lineWidth: Theme.Stroke.focus)
        .allowsHitTesting(false)
    }
  }
}

// MARK: - 行内动作按钮

/// 设置窗口里的动作按钮：一行的右端那个。
struct SettingsActionButtonStyle: ButtonStyle {
  /// 留给以后的主操作；本轮没有调用方。
  var primary = false

  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    Surface(primary: primary, enabled: isEnabled, pressed: configuration.isPressed) {
      configuration.label
    }
    .modifier(ButtonPressFeedback(isPressed: configuration.isPressed))
  }

  /// 悬停要自己的 `@State`，而 `makeBody` 不是视图，存不住状态。
  private struct Surface<Label: View>: View {
    let primary: Bool
    let enabled: Bool
    let pressed: Bool
    @ViewBuilder let label: () -> Label

    @State private var hovering = false

    private var foreground: Color {
      if !enabled {
        // 整体调暗会连边框一起吞掉；只让字退下去，边框留着说明这里有个按钮。
        return Theme.inkTertiary
      }
      return primary ? Theme.onFill : Theme.ink
    }

    private var background: Color {
      if primary && enabled {
        return Theme.fill
      }
      if pressed {
        return Theme.selected
      }
      return hovering && enabled ? Theme.hover : Theme.sunken
    }

    var body: some View {
      label()
        .font(SettingsControlMetrics.font)
        .lineLimit(1)
        // 文案照自己的宽度撑开：按钮可以比 `minWidth` 宽，但不可以吃掉字。
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(foreground)
        .padding(.horizontal, SettingsControlMetrics.inset)
        .frame(minWidth: SettingsControlMetrics.minWidth)
        .frame(height: SettingsControlMetrics.height)
        .background(
          background,
          in: RoundedRectangle(cornerRadius: SettingsControlMetrics.radius, style: .continuous)
        )
        .overlay {
          RoundedRectangle(cornerRadius: SettingsControlMetrics.radius, style: .continuous)
            .strokeBorder(
              primary && enabled ? .clear : Theme.strokeStrong,
              lineWidth: Theme.Stroke.hairline
            )
            .allowsHitTesting(false)
        }
        .opacity(primary && enabled && pressed ? 0.78 : 1)
        .contentShape(RoundedRectangle(cornerRadius: SettingsControlMetrics.radius, style: .continuous))
        .onHover { hovering = $0 }
    }
  }
}

// MARK: - 弹出列表

struct SettingsChoice<Value: Hashable>: Identifiable {
  let id: Value
  let title: String
  /// SF Symbol；和 `image` 二选一。
  var symbol: String? = nil
  /// 应用图标，16pt。
  var image: NSImage? = nil
}

private struct ChoiceIcon<Value: Hashable>: View {
  let choice: SettingsChoice<Value>

  var body: some View {
    Group {
      if let image = choice.image {
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
          .frame(width: 16, height: 16)
      } else if let symbol = choice.symbol {
        Image(systemName: symbol)
          .font(.system(size: 13, weight: .medium))
          .frame(width: 16, height: 16)
      }
    }
    .accessibilityHidden(true)
  }
}

/// popover 里的一列选项：标题、可滚动的行、可选的固定底项。
///
/// 指针悬停高亮、↑↓ 移动、Return / Space 选中、Esc 关闭；已经在结果里的行打勾
/// 并禁用——不给「点了没反应」留位置。
struct SettingsChoiceList<Value: Hashable>: View {
  let title: String
  /// 当前值，只决定初始高亮与哪一行打勾。
  let selection: Value
  let choices: [SettingsChoice<Value>]
  /// `accessibilityIdentifier` 前缀。
  let identifier: String
  var disabledValues: Set<Value> = []
  /// 分隔线下那一项，不参与滚动。
  var footer: SettingsChoice<Value>?
  let select: (Value) -> Void
  let dismiss: () -> Void

  @State private var highlighted: Value?
  @State private var pointerLocation = NSEvent.mouseLocation
  @FocusState private var focused: Bool

  /// 行与行之间；滚动区高度也按它算。
  private static var rowGap: CGFloat { 2 }
  /// 十行左右就该滚了，再高会顶到屏幕边缘。
  private static var maxListHeight: CGFloat { 286 }

  private var allChoices: [SettingsChoice<Value>] {
    choices + (footer.map { [$0] } ?? [])
  }

  private var enabledChoices: [SettingsChoice<Value>] {
    allChoices.filter { !disabledValues.contains($0.id) }
  }

  private var listHeight: CGFloat {
    let full = CGFloat(choices.count) * (SettingsControlMetrics.height + Self.rowGap) - Self.rowGap
    return min(max(full, 0), Self.maxListHeight)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Space.hairGap) {
      Text(title)
        .font(Theme.caption)
        .foregroundStyle(Theme.inkSecondary)
        .padding(.horizontal, Theme.Space.tight)
        .padding(.vertical, Theme.Space.hairGap)
        .accessibilityAddTraits(.isHeader)

      ScrollViewReader { reader in
        ScrollView {
          VStack(spacing: Self.rowGap) {
            ForEach(choices) { choice in
              row(choice).id(choice.id)
            }
          }
        }
        .frame(height: listHeight)
        .scrollBounceBehavior(.basedOnSize)
        .onChange(of: highlighted) { _, value in
          if let value, value != footer?.id {
            reader.scrollTo(value)
          }
        }
      }

      if let footer {
        Rectangle()
          .fill(Theme.stroke)
          .frame(height: Theme.Stroke.hairline)
          .padding(.vertical, Theme.Space.hairGap)
        row(footer)
      }
    }
    .padding(Theme.Space.tight)
    .background(Theme.raised)
    .focusable()
    .focused($focused)
    .focusEffectDisabled()
    .onAppear {
      highlighted = enabledChoices.contains { $0.id == selection }
        ? selection
        : enabledChoices.first?.id
      focused = true
    }
    .onChange(of: enabledChoices.map(\.id)) { _, ids in
      if !ids.contains(where: { $0 == highlighted }) {
        highlighted = ids.first
      }
      if ids.isEmpty {
        dismiss()
      }
    }
    .onKeyPress(.downArrow) { move(1); return .handled }
    .onKeyPress(.upArrow) { move(-1); return .handled }
    .onKeyPress(.return) { commit(); return .handled }
    .onKeyPress(.space) { commit(); return .handled }
    .onExitCommand(perform: dismiss)
    .accessibilityElement(children: .contain)
  }

  private func row(_ choice: SettingsChoice<Value>) -> some View {
    let disabled = disabledValues.contains(choice.id)
    return Button {
      select(choice.id)
    } label: {
      HStack(spacing: Theme.Space.tight) {
        ChoiceIcon(choice: choice)
        Text(choice.title)
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer(minLength: Theme.Space.tight)
        Image(systemName: "checkmark")
          .font(.system(size: 11, weight: .semibold))
          .opacity(selection == choice.id || disabled ? 1 : 0)
          .accessibilityHidden(true)
      }
      .font(SettingsControlMetrics.font)
      .foregroundStyle(disabled ? Theme.inkSecondary : Theme.ink)
      .padding(.horizontal, Theme.Space.tight)
      .frame(height: SettingsControlMetrics.height)
      .background(
        highlighted == choice.id && !disabled ? Theme.selected : .clear,
        in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
      )
      .opacity(disabled ? 0.6 : 1)
      .contentShape(Rectangle())
    }
    .buttonStyle(PlainPressButtonStyle(staticFeedback: true))
    .focusable(false)
    .disabled(disabled)
    .onContinuousHover { phase in
      guard case .active = phase, !disabled else {
        return
      }
      let location = NSEvent.mouseLocation
      // 指针没动过就不抢高亮：↑↓ 走到别处后，静止的指针底下换了一行，
      // 那不是用户在指它。
      guard location != pointerLocation else {
        return
      }
      pointerLocation = location
      highlighted = choice.id
    }
    .accessibilityAddTraits(selection == choice.id || disabled ? [.isSelected] : [])
    .accessibilityIdentifier(identifier + ".option.\(choice.id)")
  }

  private func move(_ offset: Int) {
    guard !enabledChoices.isEmpty else {
      return
    }
    let index = enabledChoices.firstIndex { $0.id == highlighted } ?? 0
    highlighted = enabledChoices[min(max(index + offset, 0), enabledChoices.count - 1)].id
  }

  private func commit() {
    guard let highlighted, enabledChoices.contains(where: { $0.id == highlighted }) else {
      return
    }
    select(highlighted)
  }
}
