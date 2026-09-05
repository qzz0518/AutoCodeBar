import SwiftUI

import AutoCodeBarCore

struct SourcesPane: View {
  let state: AppState

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      SettingsSection(title: L10n.text("数据来源"), systemImage: "tray.and.arrow.down", spacing: 14) {
        ForEach(SourceKind.allCases, id: \.self) { kind in
          SourceRow(state: state, kind: kind)
          if kind == .notificationCenter {
            IgnoredAppsList(state: state)
          }
        }
      }

      Notice(
        text: L10n.text("短信和邮件都需要「完整磁盘访问」。授权后如仍显示未授权，请重新启动应用。"),
        tone: .info
      ) {
        Button(L10n.text("重新启动")) { Relauncher.relaunch() }
          .buttonStyle(SettingsActionButtonStyle())
      }
    }
  }
}

private struct SourceRow: View {
  let state: AppState
  let kind: SourceKind

  private var status: SourceStatus {
    state.sourceStatuses[kind] ?? .off
  }

  private var pill: (text: String, tone: StatusPill.Tone, pulses: Bool) {
    switch status {
    case .off: (L10n.text("已关闭"), .neutral, false)
    case .starting: (L10n.text("启动中"), .neutral, true)
    case .running: (L10n.text("正在监听"), .live, false)
    case .needsFullDiskAccess: (L10n.text("需要授权"), .warn, false)
    case .unavailable: (L10n.text("不可用"), .neutral, false)
    case .failed: (L10n.text("失败"), .bad, false)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      SettingRow(title: kind.fullName, detail: kind.detail, alignment: .center) {
        HStack(spacing: 10) {
          StatusPill(text: pill.text, tone: pill.tone, pulses: pill.pulses)
          // 标题留给旁白：画出来的开关自己不说自己管的是哪一项。
          Toggle(kind.fullName, isOn: Binding(
            get: { state.settings.isEnabled(kind) },
            set: { state.setSource(kind, enabled: $0) }
          ))
          .toggleStyle(DrawnSwitchToggleStyle())
          .labelsHidden()
        }
      }

      switch status {
      case .needsFullDiskAccess:
        Notice(text: L10n.text("需要完整磁盘访问。"), tone: .warn) {
          Button(L10n.text("打开系统设置")) { state.openFullDiskAccessSettings() }
            .buttonStyle(SettingsActionButtonStyle())
        }
      case .unavailable(let message), .failed(let message):
        Notice(text: message, tone: .bad) {
          Button(L10n.text("重试")) { state.retryFailedSources() }
            .buttonStyle(SettingsActionButtonStyle())
        }
      case .off, .starting, .running:
        EmptyView()
      }
    }
  }
}
