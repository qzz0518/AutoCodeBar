import SwiftUI

import AutoCodeBarCore

// MARK: - 页面骨架

/// 有标题的区块：安静的标签、一条横线，然后是行。行之间用留白分隔，
/// 标签下的那条线就是设置分组唯一需要的分隔。
struct SettingsSection<Content: View>: View {
  let title: String
  var systemImage: String?
  var spacing: CGFloat = 16
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 7) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(Theme.inkSecondary)
        }
        Text(title)
          .font(Theme.label)
          .foregroundStyle(Theme.inkSecondary)
      }
      .padding(.bottom, 8)

      Rectangle()
        .fill(Theme.stroke)
        .frame(height: Theme.Stroke.hairline)
        .padding(.bottom, 10)

      VStack(alignment: .leading, spacing: spacing) {
        content()
      }
    }
    .accessibilityElement(children: .contain)
  }
}

/// 左边标题 + 说明，右边一个控件。
struct SettingRow<Control: View>: View {
  let title: String
  var detail: String?
  var alignment: VerticalAlignment = .top
  @ViewBuilder var control: () -> Control

  var body: some View {
    HStack(alignment: alignment, spacing: Theme.Space.regular) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(Theme.heading)
          .foregroundStyle(Theme.ink)
        if let detail {
          Text(detail)
            .font(Theme.caption)
            .foregroundStyle(Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: Theme.Space.snug)
      control()
    }
  }
}

extension SettingRow where Control == EmptyView {
  init(title: String, detail: String? = nil, alignment: VerticalAlignment = .top) {
    self.init(title: title, detail: detail, alignment: alignment, control: { EmptyView() })
  }
}

/// 柔和的填充块，用于说明、隐私声明和摘要。
struct Panel<Content: View>: View {
  var padding: CGFloat = 18
  var tone: Color = Theme.sunken
  @ViewBuilder var content: () -> Content

  var body: some View {
    content()
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(tone, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
  }
}

/// 一条行内提示：图标、一句话、按严重程度着色，可选一个尾随控件。
/// 指出问题的提示应该同时带上解决它的按钮。
struct Notice<Trailing: View>: View {
  enum Tone { case info, good, warn, bad }

  let text: String
  var tone: Tone = .info
  var systemImage: String?
  @ViewBuilder var trailing: () -> Trailing

  private var colors: (fore: Color, back: Color, icon: String) {
    switch tone {
    case .info: (Theme.inkSecondary, Theme.sunken, "info.circle")
    case .good: (Theme.positive, Theme.positiveSoft, "checkmark.circle")
    case .warn: (Theme.warning, Theme.warningSoft, "exclamationmark.triangle")
    case .bad: (Theme.danger, Theme.dangerSoft, "exclamationmark.octagon")
    }
  }

  var body: some View {
    HStack(alignment: .top, spacing: 9) {
      Image(systemName: systemImage ?? colors.icon)
        .font(.system(size: 12.5, weight: .semibold))
        .foregroundStyle(colors.fore)
        .padding(.top, 1)
        .accessibilityHidden(true)
      Text(text)
        .font(Theme.caption)
        .foregroundStyle(tone == .info ? Theme.inkSecondary : colors.fore)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: Theme.Space.snug)
      trailing()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(colors.back, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    .accessibilityElement(children: .contain)
  }
}

extension Notice where Trailing == EmptyView {
  init(text: String, tone: Tone = .info, systemImage: String? = nil) {
    self.init(text: text, tone: tone, systemImage: systemImage, trailing: { EmptyView() })
  }
}

// MARK: - 按钮

/// 按下时轻轻缩一下——控件对指针有反应，是「它收到了」最便宜的证据。
///
/// 列表行这类本来就有高亮底色的地方给 `staticFeedback`：底色已经在说话，
/// 再缩一次只会让一整列行跟着抖。
struct ButtonPressFeedback: ViewModifier {
  let isPressed: Bool
  var staticFeedback = false

  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    content
      .scaleEffect(isPressed && isEnabled && !staticFeedback && !reduceMotion ? 0.96 : 1)
      .animation(reduceMotion || staticFeedback ? nil : Theme.Motion.ui, value: isPressed)
  }
}

/// `.plain` 加上按下反馈：自绘的行与卡片按钮用它。
struct PlainPressButtonStyle: ButtonStyle {
  var staticFeedback = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .modifier(ButtonPressFeedback(isPressed: configuration.isPressed, staticFeedback: staticFeedback))
  }
}

/// 主操作：高对比药丸。浅色下黑，深色下白。
struct InkButtonStyle: ButtonStyle {
  var wide = false
  var staticFeedback = false
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13.5, weight: .semibold))
      // 把高对比药丸调暗只会留下一块吵闹的灰板。禁用的主操作应该退回到
      // 它所在卡片的层次上。
      .foregroundStyle(isEnabled ? Theme.onFill : Theme.inkTertiary)
      .padding(.horizontal, 22)
      .padding(.vertical, 10)
      .frame(maxWidth: wide ? .infinity : nil)
      .background(isEnabled ? Theme.fill : Theme.sunken, in: Capsule(style: .continuous))
      .opacity(isEnabled && configuration.isPressed ? 0.78 : 1)
      .contentShape(Capsule())
      .animation(Theme.Motion.reduced(Theme.Motion.ui), value: configuration.isPressed)
      .modifier(ButtonPressFeedback(isPressed: configuration.isPressed, staticFeedback: staticFeedback))
  }
}

/// 次操作：页面底色上的描边药丸。
struct GhostButtonStyle: ButtonStyle {
  var wide = false
  var staticFeedback = false
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13.5, weight: .medium))
      .foregroundStyle(Theme.ink)
      .padding(.horizontal, 18)
      .padding(.vertical, 9)
      .frame(maxWidth: wide ? .infinity : nil)
      .background(configuration.isPressed ? Theme.hover : Theme.surface, in: Capsule(style: .continuous))
      .overlay(Capsule(style: .continuous).strokeBorder(Theme.strokeStrong, lineWidth: Theme.Stroke.hairline))
      .opacity(isEnabled ? 1 : 0.35)
      .contentShape(Capsule())
      .modifier(ButtonPressFeedback(isPressed: configuration.isPressed, staticFeedback: staticFeedback))
  }
}

/// 卡片内部的三级操作：比脚下的底色高一档，外加一圈边。
///
/// 原来的默认底色是 `Theme.sunken`，而它经常正好落在同样是 `sunken` 的卡片上，
/// 药丸整个消失，只剩一行没人认得出是按钮的字。抬到 `hover` 再补一根发丝线，
/// 无论踩在哪层底色上都还是个控件。
struct SoftButtonStyle: ButtonStyle {
  var tone: Color = Theme.hover
  var foreground: Color = Theme.ink
  var staticFeedback = false
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12.5, weight: .medium))
      .foregroundStyle(foreground)
      .padding(.horizontal, 14)
      .padding(.vertical, 7)
      .background(configuration.isPressed ? Theme.selected : tone, in: Capsule(style: .continuous))
      .overlay(Capsule(style: .continuous).strokeBorder(Theme.stroke, lineWidth: Theme.Stroke.hairline))
      .opacity(isEnabled ? 1 : 0.35)
      .contentShape(Capsule())
      .modifier(ButtonPressFeedback(isPressed: configuration.isPressed, staticFeedback: staticFeedback))
  }
}

/// 工具栏与卡片角落里的纯图标操作。
struct IconButtonStyle: ButtonStyle {
  var size: CGFloat = 28
  var staticFeedback = false
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12.5, weight: .medium))
      .foregroundStyle(Theme.inkSecondary)
      .frame(width: size, height: size)
      .background(
        Circle().fill(configuration.isPressed ? Theme.selected : Color.clear)
      )
      .opacity(isEnabled ? 1 : 0.35)
      .contentShape(Circle())
      .modifier(ButtonPressFeedback(isPressed: configuration.isPressed, staticFeedback: staticFeedback))
  }
}

// MARK: - 开关

/// 开关，自己画而不是给系统的上色。
///
/// `.toggleStyle(.switch).tint(...)` 在深色下会被 AppKit 按约 30% 叠在面板上，
/// 开与关的轨道只差 1.8:1，一页五个开关全靠旋钮位置分辨。轨道因此归自己画。
/// 名字里带「Drawn」，是为了和 SwiftUI 自己那个同名类型分开。
struct DrawnSwitchToggleStyle: ToggleStyle {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// 照系统开关的常规尺寸，界面里这个开关就还是 macOS 上的同一个物件。
  private static let width: CGFloat = 38
  private static let height: CGFloat = 22
  private static let knob: CGFloat = 18
  private static let inset: CGFloat = 2
  /// 旋钮从左端到右端要走的距离。
  private static let travel = width - knob - inset * 2
  /// 关着的轨道在深色下本身就暗，旋钮得比它亮才看得见。
  private static let unlitKnob = Color.dynamic(light: 0xFFFFFF, dark: 0xC9C9CF)

  func makeBody(configuration: Configuration) -> some View {
    let isOn = configuration.isOn
    let animation = Theme.Motion.reduced(Theme.Motion.ui, reduceMotion)
    Button {
      // 显式带上动画：绑定写进模型再回流到视图，靠隐式动画不一定接得住。
      withAnimation(animation) {
        configuration.isOn.toggle()
      }
    } label: {
      ZStack(alignment: .leading) {
        // 圆形旋钮配圆头轨道；连续圆角的胶囊在两端会比旋钮更方。
        Capsule()
          .fill(isOn ? Theme.controlOn : Theme.strokeStrong)
          .frame(width: Self.width, height: Self.height)
        Circle()
          .fill(isOn ? Color.white : Self.unlitKnob)
          .frame(width: Self.knob, height: Self.knob)
          .shadow(color: .black.opacity(0.20), radius: 1, y: 0.5)
          // 用位移而不是换 ZStack 的对齐：位移是可动画的量，对齐不是。
          .offset(x: Self.inset + (isOn ? Self.travel : 0))
      }
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .opacity(isEnabled ? 1 : 0.35)
    .animation(animation, value: isOn)
    // 画出来的轨道自己没有语义。这里重建一个系统开关，只给旁白读，永不渲染，
    // 控件因此仍然报自己是开关，并带上调用方给的标题。
    .accessibilityRepresentation {
      Toggle(isOn: configuration.$isOn) { configuration.label }
        .toggleStyle(.switch)
    }
  }
}

// MARK: - 输入

/// 文本输入与文本编辑共用的边框。
struct FieldBox<Content: View>: View {
  var width: CGFloat?
  @ViewBuilder var content: () -> Content

  @FocusState private var focused: Bool
  @State private var hovering = false

  var body: some View {
    content()
      .textFieldStyle(.plain)
      .font(Theme.body)
      .foregroundStyle(Theme.ink)
      .focused($focused)
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .frame(width: width)
      .background(
        hovering && !focused ? Theme.hover : Theme.surface,
        in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
          // 边框要在自己的填充色上说清「这里能打字」；聚焦时同一圈线加粗成墨色，
          // 不必再叠一个系统焦点环。
          .strokeBorder(
            focused ? Theme.ink : Theme.inputStroke,
            lineWidth: focused ? Theme.Stroke.focus : Theme.Stroke.hairline
          )
      )
      .focusEffectDisabled()
      .onHover { hovering = $0 }
  }
}

// MARK: - 状态

struct StatusPill: View {
  enum Tone { case neutral, live, warn, bad }

  let text: String
  var tone: Tone = .neutral
  var pulses = false

  @State private var glow = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var color: Color {
    switch tone {
    case .neutral: Theme.inkSecondary
    case .live: Theme.positive
    case .warn: Theme.warning
    case .bad: Theme.danger
    }
  }

  /// 中性底色是 `selected` 而不是 `sunken`：药丸常常正落在同样 `sunken` 的
  /// 卡片上，那时它根本没画出胶囊，同一列里带底色的和不带底色的混在一起，
  /// 看着像有几行没做完。
  private var background: Color {
    switch tone {
    case .neutral: Theme.selected
    case .live: Theme.positiveSoft
    case .warn: Theme.warningSoft
    case .bad: Theme.dangerSoft
    }
  }

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(color)
        .frame(width: 6, height: 6)
        .opacity(pulses && glow && !reduceMotion ? 0.35 : 1)
      Text(text)
        .font(.system(size: 11.5, weight: .semibold))
        .foregroundStyle(color)
        .fixedSize()
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 4)
    .background(background, in: Capsule(style: .continuous))
    .accessibilityElement(children: .combine)
    .onAppear {
      guard pulses, !reduceMotion else { return }
      withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
        glow = true
      }
    }
  }
}

/// 清单里的一项要求：满足时是实心勾，不满足时右边给出操作按钮。
struct ChecklistRow<Trailing: View>: View {
  let done: Bool
  let title: String
  var detail: String?
  var busy = false
  @ViewBuilder var trailing: () -> Trailing

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      ZStack {
        Circle()
          .fill(done ? Theme.fill : Theme.surface)
          .frame(width: 22, height: 22)
          .overlay(
            Circle().strokeBorder(done ? Color.clear : Theme.strokeStrong, lineWidth: Theme.Stroke.hairline)
          )
        if busy {
          ProgressView().controlSize(.small).scaleEffect(0.6)
        } else if done {
          Image(systemName: "checkmark")
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(Theme.onFill)
        }
      }
      .accessibilityLabel(done ? L10n.text("已完成") : L10n.text("未完成"))

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(Theme.heading)
          .foregroundStyle(Theme.ink)
        if let detail {
          Text(detail)
            .font(Theme.caption)
            .foregroundStyle(Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      Spacer(minLength: Theme.Space.snug)
      trailing()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(Theme.sunken, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
  }
}

extension ChecklistRow where Trailing == EmptyView {
  init(done: Bool, title: String, detail: String? = nil, busy: Bool = false) {
    self.init(done: done, title: title, detail: detail, busy: busy, trailing: { EmptyView() })
  }
}

/// 引导进度：步骤名平铺，当前那个用墨色并在下面画一条线。
struct StepBar: View {
  let steps: [String]
  let current: Int

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
        VStack(spacing: 9) {
          Text(step)
            .font(.system(size: 13, weight: index == current ? .semibold : .regular))
            .foregroundStyle(index == current ? Theme.ink : Theme.inkTertiary)
          Rectangle()
            .fill(index == current ? Theme.ink : Color.clear)
            .frame(height: 2)
        }
        .frame(width: 108)
        .contentShape(Rectangle())

        if index < steps.count - 1 {
          Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Theme.inkTertiary)
            .padding(.bottom, 11)
            .padding(.horizontal, 4)
        }
      }
    }
    .animation(Theme.Motion.reduced(Theme.Motion.ui), value: current)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(L10n.format("第 %d 步，共 %d 步", current + 1, steps.count))
  }
}

/// 引导窗口右半边的柔焦渐变——不用配图也能给出氛围。
struct AuroraBackdrop: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color.dynamic(light: 0xDCEFEC, dark: 0x0F2320),
          Color.dynamic(light: 0xF2F6F5, dark: 0x0F1116)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      Circle()
        .fill(Theme.accent.opacity(0.18))
        .frame(width: 380, height: 380)
        .blur(radius: 90)
        .offset(x: -60, y: -140)
      Circle()
        .fill(Color.dynamic(light: 0xB6E5DE, dark: 0x14504A).opacity(0.5))
        .frame(width: 320, height: 320)
        .blur(radius: 100)
        .offset(x: 90, y: 180)
    }
    .accessibilityHidden(true)
  }
}

/// 应用图标 + 名称。
struct WordMark: View {
  var size: CGFloat = 15

  private var tile: CGFloat { size + 3 }

  var body: some View {
    HStack(spacing: 8) {
      Image(nsImage: NSApp.applicationIconImage ?? NSImage())
        .resizable()
        .interpolation(.high)
        .frame(width: tile, height: tile)
      Text(verbatim: "AutoCodeBar")
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(Theme.ink)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: "AutoCodeBar"))
  }
}
