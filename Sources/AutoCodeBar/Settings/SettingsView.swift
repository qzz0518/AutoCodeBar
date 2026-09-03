import AppKit
import SwiftUI

import AutoCodeBarCore

/// 外部链接常量。
enum AppLinks {
  static let github = "https://github.com/qzz0518/AutoCodeBar"
  static let x = "https://x.com/zerah_eth"

  static func open(_ urlString: String) {
    guard let url = URL(string: urlString) else {
      return
    }
    NSWorkspace.shared.open(url)
  }
}

enum SettingsTab: String, CaseIterable, Identifiable {
  case general
  case sources
  case rules
  case permissions
  case about

  var id: String { rawValue }

  var title: String {
    switch self {
    case .general: L10n.text("通用")
    case .sources: L10n.text("来源")
    case .rules: L10n.text("规则")
    case .permissions: L10n.text("权限")
    case .about: L10n.text("关于")
    }
  }

  var symbol: String {
    switch self {
    case .general: "slider.horizontal.3"
    case .sources: "tray.and.arrow.down"
    case .rules: "text.magnifyingglass"
    case .permissions: "checkmark.shield"
    case .about: "info.circle"
    }
  }
}

/// 设置：左边一列安静的导航，右边一栏滚动内容。
struct SettingsView: View {
  let state: AppState

  @State private var tab: SettingsTab

  /// `initialTab` 决定窗口打开时停在哪一页。
  init(state: AppState, initialTab: SettingsTab = .general) {
    self.state = state
    _tab = State(initialValue: initialTab)
  }

  var body: some View {
    HStack(spacing: 0) {
      // 导航列从窗口顶部铺到底部，交通灯直接叠在它上面。
      nav
        .frame(width: 200)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.sunken)

      ZStack {
        Theme.raised
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            Text(tab.title)
              .font(.system(size: 26, weight: .bold))
              .foregroundStyle(Theme.ink)
              .padding(.bottom, 16)

            content
          }
          .padding(.horizontal, 34)
          .padding(.top, 20)
          .padding(.bottom, 20)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
      }
    }
    .frame(width: 800, height: 580)
    .background(Theme.raised)
    .onAppear { state.refreshPermissions() }
    .onReceive(NotificationCenter.default.publisher(
      for: NSApplication.didBecomeActiveNotification
    )) { _ in state.refreshPermissions() }
  }

  private var nav: some View {
    VStack(alignment: .leading, spacing: 2) {
      ForEach(SettingsTab.allCases) { item in
        SettingsNavItem(tab: item, isSelected: tab == item) { tab = item }
      }
      Spacer()
    }
    .padding(.horizontal, 10)
    // 顶部留出交通灯的位置。
    .padding(.top, 38)
    .padding(.bottom, 16)
  }

  @ViewBuilder
  private var content: some View {
    switch tab {
    case .general: GeneralPane(state: state)
    case .sources: SourcesPane(state: state)
    case .rules: RulesPane(state: state)
    case .permissions: PermissionsPane(state: state)
    case .about: AboutPane(state: state)
    }
  }
}

private struct SettingsNavItem: View {
  let tab: SettingsTab
  let isSelected: Bool
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: tab.symbol)
          .font(.system(size: 12.5, weight: .medium))
          .frame(width: 16)
        Text(tab.title)
          .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
        Spacer(minLength: 0)
      }
      .foregroundStyle(isSelected ? Theme.ink : Theme.inkSecondary)
      .padding(.horizontal, 11)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
          .fill(isSelected ? Theme.selected : (hovering ? Theme.hover : Color.clear))
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focusEffectDisabled()
    .onHover { hovering = $0 }
  }
}

/// 一条授权：右边状态药丸，缺什么时才给修复按钮。
struct PermissionRow<Action: View>: View {
  let title: String
  let detail: String
  let granted: Bool
  var grantedText: String = L10n.text("已授权")
  var missingText: String = L10n.text("未授权")
  var missingTone: StatusPill.Tone = .warn
  var showsAction: Bool = true
  @ViewBuilder let action: () -> Action

  var body: some View {
    SettingRow(title: title, detail: detail, alignment: .center) {
      HStack(spacing: 8) {
        StatusPill(
          text: granted ? grantedText : missingText,
          tone: granted ? .live : missingTone
        )
        if granted == false, showsAction {
          action()
        }
      }
    }
  }
}
