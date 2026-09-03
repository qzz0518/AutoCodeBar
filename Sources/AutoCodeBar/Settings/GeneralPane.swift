import SwiftUI

import AutoCodeBarCore

struct GeneralPane: View {
  let state: AppState

  @State private var launchAtLogin = LaunchAtLogin.isEnabled

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      SettingsSection(title: L10n.text("启动"), systemImage: "power") {
        SettingRow(
          title: L10n.text("登录时自动启动"),
          detail: L10n.text("开机后静默出现在菜单栏。"),
          alignment: .center
        ) {
          Toggle("", isOn: Binding(
            get: { launchAtLogin },
            set: { newValue in
              launchAtLogin = newValue
              state.setLaunchAtLogin(newValue)
              launchAtLogin = LaunchAtLogin.isEnabled
            }
          ))
          .toggleStyle(.switch)
          .tint(Theme.controlOn)
          .labelsHidden()
        }

        if let error = state.launchAtLoginError {
          Notice(text: error, tone: .bad)
        }
      }

      SettingsSection(title: L10n.text("复制后"), systemImage: "doc.on.clipboard") {
        SettingRow(
          title: L10n.text("显示系统通知"),
          detail: L10n.text("横幅显示验证码与来源。"),
          alignment: .center
        ) {
          Toggle("", isOn: Binding(
            get: { state.settings.showCopyNotification },
            set: { state.settings.showCopyNotification = $0 }
          ))
          .toggleStyle(.switch)
          .tint(Theme.controlOn)
          .labelsHidden()
        }

        SettingRow(
          title: L10n.text("在菜单栏短暂显示验证码"),
          detail: L10n.text("约 15 秒后自动隐藏。"),
          alignment: .center
        ) {
          Toggle("", isOn: Binding(
            get: { state.settings.showCodeInMenuBar },
            set: { state.settings.showCodeInMenuBar = $0 }
          ))
          .toggleStyle(.switch)
          .tint(Theme.controlOn)
          .labelsHidden()
        }
      }

      SettingsSection(title: L10n.text("软件更新"), systemImage: "arrow.triangle.2.circlepath") {
        SettingRow(
          title: L10n.text("自动检查更新"),
          detail: L10n.text("每天检查一次，由 Sparkle 安全下载并安装。"),
          alignment: .center
        ) {
          Toggle("", isOn: Binding(
            get: { state.updater.automaticallyChecksForUpdates },
            set: { state.updater.automaticallyChecksForUpdates = $0 }
          ))
          .toggleStyle(.switch)
          .tint(Theme.controlOn)
          .labelsHidden()
        }

        SettingRow(
          title: L10n.text("当前版本"),
          detail: AppVersion.short + " (" + AppVersion.build + ")",
          alignment: .center
        ) {
          Button(L10n.text("检查更新…")) { state.updater.checkForUpdates() }
            .buttonStyle(SoftButtonStyle())
            .disabled(!state.updater.canCheckForUpdates)
        }
      }

      SettingsSection(title: L10n.text("设置向导"), systemImage: "checklist") {
        SettingRow(
          title: L10n.text("重新运行设置向导"),
          detail: L10n.text("从权限开始重新走一遍。"),
          alignment: .center
        ) {
          Button(L10n.text("重新运行")) { state.restartOnboarding() }
            .buttonStyle(SoftButtonStyle())
        }
      }
    }
    .onAppear {
      launchAtLogin = LaunchAtLogin.isEnabled
    }
  }
}
