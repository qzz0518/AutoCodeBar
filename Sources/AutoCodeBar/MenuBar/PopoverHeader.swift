import SwiftUI

import AutoCodeBarCore

struct PopoverHeader: View {
  let state: AppState
  let openSettings: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var pulse = false

  private var isStarting: Bool {
    state.settings.enabledSources.contains { state.sourceStatuses[$0] == .starting }
  }

  private var dotColor: Color {
    switch state.overall {
    case .running: return Theme.positive
    case .paused: return Theme.inkTertiary
    case .needsFullDiskAccess: return Theme.warning
    case .failed: return Theme.danger
    case .noSources: return Theme.inkTertiary
    }
  }

  private var title: String {
    switch state.overall {
    case .running: return L10n.text("正在监听")
    case .paused: return L10n.text("已暂停")
    case .needsFullDiskAccess: return L10n.text("需要授权")
    case .failed: return L10n.text("无法监听")
    case .noSources: return L10n.text("未启用来源")
    }
  }

  private var subtitle: String {
    switch state.overall {
    case .running(let sources):
      return sources.isEmpty
        ? L10n.text("启动中…")
        : sources.map(\.shortName).joined(separator: " · ")
    case .paused:
      return L10n.text("点击右侧按钮恢复")
    case .needsFullDiskAccess:
      return L10n.text("授予完整磁盘访问后自动恢复")
    case .failed:
      return L10n.text("所有来源都启动失败")
    case .noSources:
      return L10n.text("在设置中开启至少一个来源")
    }
  }

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      Circle()
        .fill(dotColor)
        .frame(width: 8, height: 8)
        .opacity(isStarting && !reduceMotion ? (pulse ? 1 : 0.4) : 1)
        .onAppear {
          guard isStarting, !reduceMotion else {
            return
          }
          withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulse = true
          }
        }

      VStack(alignment: .leading, spacing: 1) {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
        Text(subtitle)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 4)

      Button {
        if state.isPaused {
          state.resume()
        } else {
          state.pause()
        }
      } label: {
        Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
          .frame(width: 24, height: 24)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .focusEffectDisabled()
      .help(state.isPaused ? L10n.text("恢复监听") : L10n.text("暂停监听"))

      #if DEBUG
      if DebugSnapshot.isActive {
        // ImageRenderer 画不出 Menu，截图时用同尺寸的静态齿轮占位。
        Image(systemName: "gearshape")
          .frame(width: 24, height: 24)
      } else {
        gearMenu
      }
      #else
      gearMenu
      #endif
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }

  private var gearMenu: some View {
    Menu {
      Button(L10n.text("设置…")) { openSettings() }
        .keyboardShortcut(",", modifiers: .command)
      Button(L10n.text("检查更新…")) { state.updater.checkForUpdates() }
        .disabled(!state.updater.canCheckForUpdates)
      Button(L10n.text("关于 AutoCodeBar")) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
      }
      Divider()
      Button(L10n.text("退出")) { NSApp.terminate(nil) }
        .keyboardShortcut("q", modifiers: .command)
    } label: {
      Image(systemName: "gearshape")
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .focusEffectDisabled()
    .frame(width: 24, height: 24)
    .help(L10n.text("更多"))
  }
}
