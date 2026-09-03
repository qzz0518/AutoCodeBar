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
            IgnoredAppsPanel(state: state)
          }
        }
      }

      Notice(
        text: L10n.text("短信和邮件都需要「完整磁盘访问」。授权后如仍显示未授权，请重新启动应用。"),
        tone: .info
      ) {
        Button(L10n.text("重新启动")) { Relauncher.relaunch() }
          .buttonStyle(SoftButtonStyle())
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
          Toggle("", isOn: Binding(
            get: { state.settings.isEnabled(kind) },
            set: { state.setSource(kind, enabled: $0) }
          ))
          .toggleStyle(.switch)
          .tint(Theme.controlOn)
          .labelsHidden()
        }
      }

      switch status {
      case .needsFullDiskAccess:
        Notice(text: L10n.text("需要完整磁盘访问。"), tone: .warn) {
          Button(L10n.text("打开系统设置")) { state.openFullDiskAccessSettings() }
            .buttonStyle(SoftButtonStyle())
        }
      case .unavailable(let message), .failed(let message):
        Notice(text: message, tone: .bad) {
          Button(L10n.text("重试")) { state.retryFailedSources() }
            .buttonStyle(SoftButtonStyle())
        }
      case .off, .starting, .running:
        EmptyView()
      }
    }
  }
}

/// 通知忽略列表。本地缓存文本，300ms 防抖后写回设置，
/// 否则每敲一个字都会重排行，连换行都打不出来。
private struct IgnoredAppsPanel: View {
  let state: AppState

  @State private var text = ""
  @State private var didLoad = false
  @State private var commitTask: Task<Void, Never>?

  var body: some View {
    Panel {
      VStack(alignment: .leading, spacing: 8) {
        Text(L10n.text("忽略这些应用的通知"))
          .font(Theme.heading)
          .foregroundStyle(Theme.ink)

        FieldBox {
          TextEditor(text: $text)
            .font(.system(size: 11, design: .monospaced))
            .frame(height: 104)
            .scrollContentBackground(.hidden)
        }

        Text(L10n.text("默认忽略 Telegram，避免聊天内容误触发。AutoCodeBar 自身的通知始终忽略。"))
          .font(Theme.caption)
          .foregroundStyle(Theme.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .onAppear {
      guard !didLoad else {
        return
      }
      didLoad = true
      text = state.settings.ignoredNotificationApps.joined(separator: "\n")
    }
    .onChange(of: text) { _, _ in
      commitTask?.cancel()
      commitTask = Task {
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else {
          return
        }
        let apps = text
          .components(separatedBy: .newlines)
          .map { $0.trimmingCharacters(in: .whitespaces) }
          .filter { !$0.isEmpty }
        if apps != state.settings.ignoredNotificationApps {
          state.settings.ignoredNotificationApps = apps
        }
      }
    }
  }
}
