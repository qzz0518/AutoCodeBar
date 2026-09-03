import AppKit
import SwiftUI
import UserNotifications

import AutoCodeBarCore

/// 首次运行的引导：按顺序把要做的事排好，解释每个权限为什么要，
/// 而不是甩一屏勾选框。这里的每一项之后都能在设置里再找到。
struct OnboardingFlow: View {
  let state: AppState

  @State private var step: Step = Step.initial

  enum Step: Int, CaseIterable {
    case welcome, permissions, done

    /// 引导进行中写入、`finish()` 时删除。它的存在同时也是「引导未完成」的信号：
    /// 授权完整磁盘访问后 macOS 可能重启应用，引导必须回到离开时的那一步。
    static let progressKey = "onboardingStep"

    /// 欢迎页和完成页不进进度条：把它们算进去会让设置看起来长一倍。
    var barIndex: Int? {
      switch self {
      case .welcome, .done: nil
      case .permissions: 0
      }
    }

    static var initial: Step {
      if let raw = UserDefaults.standard.object(forKey: progressKey) as? Int,
         let step = Step(rawValue: raw) {
        return step
      }
      return .welcome
    }
  }

  private static var barTitles: [String] { [L10n.text("权限")] }

  private var fdaGranted: Bool {
    state.fullDiskAccess == .granted
  }

  private var notificationGranted: Bool {
    state.notificationAuth == .authorized || state.notificationAuth == .provisional
  }

  var body: some View {
    VStack(spacing: 0) {
      topBar
      Divider().overlay(Theme.stroke)
      HStack(spacing: 0) {
        leftPane
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Theme.surface)

        if step != .done {
          rightPane
            .frame(width: 300)
        }
      }
    }
    .frame(width: 920, height: 600)
    .background(Theme.surface)
    .onAppear {
      state.refreshPermissions()
      UserDefaults.standard.set(step.rawValue, forKey: Step.progressKey)
    }
    .onChange(of: step) { _, newValue in
      UserDefaults.standard.set(newValue.rawValue, forKey: Step.progressKey)
    }
    // 授权发生在这个窗口之外的系统设置里；用户切回来时行必须立刻变绿。
    .onReceive(NotificationCenter.default.publisher(
      for: NSApplication.didBecomeActiveNotification
    )) { _ in state.refreshPermissions() }
    .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
      state.refreshPermissions()
    }
    .animation(.easeInOut(duration: 0.22), value: step)
  }

  // MARK: - 外框

  private var topBar: some View {
    ZStack {
      if let index = step.barIndex {
        StepBar(steps: Self.barTitles, current: index)
      } else {
        WordMark(size: 15)
      }

      HStack {
        Spacer()
        Button(L10n.text("跳过设置")) { finish() }
          .buttonStyle(.plain)
          .focusEffectDisabled()
          .font(.system(size: 12))
          .foregroundStyle(Theme.inkTertiary)
          .padding(.trailing, 18)
          .opacity(step == .done ? 0 : 1)
      }
    }
    .frame(height: 52)
    .padding(.top, 6)
  }

  /// 刻意不用 ScrollView：引导每一步都必须一屏放得下，装不下就改文案或尺寸。
  private var leftPane: some View {
    VStack(alignment: .leading, spacing: 0) {
      switch step {
      case .welcome: welcomeStep
      case .permissions: permissionsStep
      case .done: doneStep
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 44)
    .padding(.vertical, 32)
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }

  private var rightPane: some View {
    ZStack {
      AuroraBackdrop()
      sideCard
        .frame(width: 252)
    }
  }

  @ViewBuilder
  private var sideCard: some View {
    switch step {
    case .welcome:
      CodePreviewCard()
    case .permissions:
      InfoCard(
        title: L10n.text("AutoCodeBar 会读取什么"),
        points: [
          .init(
            symbol: "internaldrive",
            title: L10n.text("只读本机数据库"),
            detail: L10n.text("「信息」的 chat.db 和「邮件」的 .emlx 文件，只读打开，不修改。")
          ),
          .init(
            symbol: "wifi.slash",
            title: L10n.text("不上传数据"),
            detail: L10n.text("没有服务器、没有统计；更新检查可以关闭。")
          ),
          .init(
            symbol: "clock.arrow.circlepath",
            title: L10n.text("历史只在内存"),
            detail: L10n.text("最多 20 条，退出应用即清空；剪贴板写入带机密标记。")
          )
        ]
      )
    case .done:
      EmptyView()
    }
  }

  // MARK: - 步骤

  private var welcomeStep: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(L10n.text("验证码，自动到剪贴板。"))
        .font(Theme.display)
        .foregroundStyle(Theme.ink)
        .fixedSize(horizontal: false, vertical: true)

      Text(L10n.text("AutoCodeBar 在本机读取「信息」和「邮件」的新内容，识别出验证码后立即复制，并在菜单栏提醒你。识别全程在本机完成。"))
        .font(.system(size: 15))
        .foregroundStyle(Theme.inkSecondary)
        .frame(maxWidth: 460, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 14)

      HStack(alignment: .top, spacing: 12) {
        FeatureTile(
          symbol: "message.fill",
          title: L10n.text("短信与 iMessage"),
          detail: L10n.text("转发到 Mac 的短信，以及 iMessage。")
        )
        FeatureTile(
          symbol: "envelope.fill",
          title: L10n.text("邮件"),
          detail: L10n.text("Apple Mail 收到的新邮件，纯文本或 HTML。")
        )
        FeatureTile(
          symbol: "doc.on.clipboard",
          title: L10n.text("直接粘贴"),
          detail: L10n.text("复制完成即可 ⌘V。历史只留在内存。")
        )
      }
      .padding(.top, 22)

      HStack(spacing: 14) {
        Button(L10n.text("开始设置")) { step = .permissions }
          .buttonStyle(InkButtonStyle())
        Text(L10n.text("大约需要一分钟。"))
          .font(Theme.caption)
          .foregroundStyle(Theme.inkTertiary)
      }
      .padding(.top, 24)
    }
  }

  private var permissionsStep: some View {
    VStack(alignment: .leading, spacing: 0) {
      StepTitle(
        title: L10n.text("让 AutoCodeBar 读到验证码"),
        subtitle: L10n.text("没有完整磁盘访问，就没有东西可识别。macOS 只会问一次。")
      )

      VStack(alignment: .leading, spacing: 10) {
        ChecklistGroupLabel(text: L10n.text("识别验证码 — 必需"), first: true)
        ChecklistRow(
          done: fdaGranted,
          title: L10n.text("完整磁盘访问"),
          detail: fdaGranted
            ? L10n.text("已可以读取「信息」与「邮件」的本地数据。")
            : L10n.text("读取「信息」与「邮件」本地数据所必需。")
        ) {
          if fdaGranted == false {
            Button(L10n.text("打开系统设置")) { state.openFullDiskAccessSettings() }
              .buttonStyle(GhostButtonStyle())
          }
        }

        ChecklistGroupLabel(text: L10n.text("提醒 — 可选"))
        ChecklistRow(
          done: notificationGranted,
          title: L10n.text("通知"),
          detail: L10n.text("复制后显示一条横幅，可选。")
        ) {
          switch state.notificationAuth {
          case .notDetermined:
            Button(L10n.text("允许…")) { state.requestNotificationAuthorization() }
              .buttonStyle(GhostButtonStyle())
          case .denied:
            Button(L10n.text("打开通知设置")) { SystemSettingsLinks.openNotifications() }
              .buttonStyle(GhostButtonStyle())
          default:
            EmptyView()
          }
        }
      }
      .padding(.top, 26)

      if state.showRelaunchHint, fdaGranted == false {
        Notice(text: L10n.text("如果已经加入列表但仍显示未授权，请重新启动 AutoCodeBar。"), tone: .info) {
          Button(L10n.text("重新启动")) { Relauncher.relaunch() }
            .buttonStyle(SoftButtonStyle())
        }
        .padding(.top, 14)
      }

      StepFooter(
        backTitle: L10n.text("返回"),
        back: { step = .welcome },
        nextTitle: L10n.text("继续"),
        nextEnabled: fdaGranted,
        next: { step = .done },
        hint: fdaGranted ? nil : L10n.text("需要完整磁盘访问才能继续。")
      )
      .padding(.top, 34)
    }
  }

  private var doneStep: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: 40)
      ZStack {
        Circle().fill(Theme.positiveSoft).frame(width: 64, height: 64)
        Image(systemName: "checkmark")
          .font(.system(size: 26, weight: .bold))
          .foregroundStyle(Theme.positive)
      }

      Text(L10n.text("准备就绪。"))
        .font(.system(size: 40, weight: .bold))
        .foregroundStyle(Theme.ink)
        .padding(.top, 24)

      Text(L10n.text("下一条验证码到达时会自动复制，菜单栏会显示它 15 秒。来源和识别规则随时可以在设置里调整。"))
        .font(.system(size: 15))
        .foregroundStyle(Theme.inkSecondary)
        .frame(maxWidth: 560, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 12)

      Text(L10n.text("菜单栏图标 › 齿轮 › 设置…"))
        .font(Theme.caption)
        .foregroundStyle(Theme.inkTertiary)
        .padding(.top, 8)

      if notificationGranted == false {
        Notice(text: L10n.text("通知未开启，复制后只会在菜单栏显示。"), tone: .info)
          .frame(maxWidth: 480)
          .padding(.top, 22)
      }

      Button(L10n.text("完成")) { finish() }
        .buttonStyle(InkButtonStyle())
        .padding(.top, 34)
      Spacer(minLength: 30)
    }
  }

  private func finish() {
    state.finishOnboarding()
  }
}

// MARK: - 零件

/// 按「这一组解锁什么」切分权限清单，「可选」在组标签上说一次，
/// 而不是在每一行的说明里含混带过。
private struct ChecklistGroupLabel: View {
  let text: String
  var first = false

  var body: some View {
    Text(text)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(Theme.inkTertiary)
      .kerning(0.4)
      .padding(.top, first ? 0 : 10)
  }
}

private struct StepTitle: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.system(size: 30, weight: .bold))
        .foregroundStyle(Theme.ink)
        .lineLimit(1)
        .fixedSize()
      Text(subtitle)
        .font(.system(size: 14))
        .foregroundStyle(Theme.inkSecondary)
        .lineLimit(1)
        .fixedSize()
    }
  }
}

private struct StepFooter: View {
  let backTitle: String
  let back: () -> Void
  let nextTitle: String
  let nextEnabled: Bool
  let next: () -> Void
  var hint: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        Button(backTitle, action: back)
          .buttonStyle(GhostButtonStyle())
        Button(nextTitle, action: next)
          .buttonStyle(InkButtonStyle())
          .disabled(nextEnabled == false)
          .keyboardShortcut(.defaultAction)
      }
      if let hint {
        Text(hint)
          .font(Theme.caption)
          .foregroundStyle(Theme.inkTertiary)
      }
    }
  }
}

/// 三块卖点卡片。160 × 126，三块加两道 12pt 间距刚好 504pt，落在左栏 532pt 的内容宽度内。
private struct FeatureTile: View {
  let symbol: String
  let title: String
  let detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: symbol)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Theme.accent)
      Text(title)
        .font(Theme.heading)
        .foregroundStyle(Theme.ink)
        .fixedSize(horizontal: false, vertical: true)
      Text(detail)
        .font(Theme.caption)
        .foregroundStyle(Theme.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(14)
    .frame(width: 160, height: 126, alignment: .topLeading)
    .background(Theme.sunken, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
  }
}

/// 应用实际产出的样子，展示而不是描述。
private struct CodePreviewCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(L10n.text("实时预览"))
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Theme.inkSecondary)

      HStack(alignment: .top, spacing: 9) {
        Image(systemName: "message.fill")
          .font(.system(size: 13))
          .foregroundStyle(Theme.inkTertiary)
          .frame(width: 18)
          .padding(.top, 3)

        VStack(alignment: .leading, spacing: 3) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "482913")
              .font(.system(size: 17, weight: .semibold, design: .monospaced))
              .foregroundStyle(Theme.ink)
            Spacer(minLength: 4)
            StatusPill(text: L10n.text("已复制"), tone: .live)
          }
          Text(verbatim: "京东 · 您的验证码为482913，5分钟内有效")
            .font(.system(size: 11))
            .foregroundStyle(Theme.inkSecondary)
            .lineLimit(1)
        }
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    .cardShadow()
  }
}

struct InfoCard: View {
  struct Point: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
  }

  let title: String
  let points: [Point]

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Theme.inkSecondary)
      ForEach(points) { point in
        HStack(alignment: .top, spacing: 11) {
          Image(systemName: point.symbol)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.accent)
            .frame(width: 18)
            .padding(.top, 1)
          VStack(alignment: .leading, spacing: 4) {
            Text(point.title)
              .font(.system(size: 13.5, weight: .semibold))
              .foregroundStyle(Theme.ink)
            Text(point.detail)
              .font(Theme.caption)
              .foregroundStyle(Theme.inkSecondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    .cardShadow()
  }
}
