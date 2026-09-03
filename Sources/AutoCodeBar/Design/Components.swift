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
        .frame(height: 1)
        .padding(.bottom, 10)

      VStack(alignment: .leading, spacing: spacing) {
        content()
      }
    }
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
  }
}

extension Notice where Trailing == EmptyView {
  init(text: String, tone: Tone = .info, systemImage: String? = nil) {
    self.init(text: text, tone: tone, systemImage: systemImage, trailing: { EmptyView() })
  }
}

// MARK: - 按钮

/// 主操作：高对比药丸。浅色下黑，深色下白。
struct InkButtonStyle: ButtonStyle {
  var wide = false
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
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

/// 次操作：页面底色上的描边药丸。
struct GhostButtonStyle: ButtonStyle {
  var wide = false
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13.5, weight: .medium))
      .foregroundStyle(Theme.ink)
      .padding(.horizontal, 18)
      .padding(.vertical, 9)
      .frame(maxWidth: wide ? .infinity : nil)
      .background(configuration.isPressed ? Theme.hover : Theme.surface, in: Capsule(style: .continuous))
      .overlay(Capsule(style: .continuous).strokeBorder(Theme.strokeStrong, lineWidth: 1))
      .opacity(isEnabled ? 1 : 0.35)
      .contentShape(Capsule())
  }
}

/// 卡片内部的三级操作：填充、无边框、紧凑。
struct SoftButtonStyle: ButtonStyle {
  var tone: Color = Theme.sunken
  var foreground: Color = Theme.ink
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12.5, weight: .medium))
      .foregroundStyle(foreground)
      .padding(.horizontal, 14)
      .padding(.vertical, 7)
      .background(configuration.isPressed ? Theme.selected : tone, in: Capsule(style: .continuous))
      .opacity(isEnabled ? 1 : 0.35)
      .contentShape(Capsule())
  }
}

/// 工具栏与卡片角落里的纯图标操作。
struct IconButtonStyle: ButtonStyle {
  var size: CGFloat = 28
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
  }
}

// MARK: - 输入

/// 文本输入与文本编辑共用的边框。
struct FieldBox<Content: View>: View {
  var width: CGFloat?
  @ViewBuilder var content: () -> Content

  var body: some View {
    content()
      .textFieldStyle(.plain)
      .font(Theme.body)
      .foregroundStyle(Theme.ink)
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .frame(width: width)
      .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
          .strokeBorder(Theme.strokeStrong, lineWidth: 1)
      )
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

  private var background: Color {
    switch tone {
    case .neutral: Theme.sunken
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
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 4)
    .background(background, in: Capsule(style: .continuous))
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
            Circle().strokeBorder(done ? Color.clear : Theme.strokeStrong, lineWidth: 1)
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
    .animation(.easeOut(duration: 0.2), value: current)
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
