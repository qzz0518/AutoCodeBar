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
          // 标题留给旁白：开关本身画出来了，可视界面里由左边那行字说明它管什么。
          Toggle(L10n.text("登录时自动启动"), isOn: Binding(
            get: { launchAtLogin },
            set: { newValue in
              launchAtLogin = newValue
              state.setLaunchAtLogin(newValue)
              launchAtLogin = LaunchAtLogin.isEnabled
            }
          ))
          .toggleStyle(DrawnSwitchToggleStyle())
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
          Toggle(L10n.text("显示系统通知"), isOn: Binding(
            get: { state.settings.showCopyNotification },
            set: { state.settings.showCopyNotification = $0 }
          ))
          .toggleStyle(DrawnSwitchToggleStyle())
          .labelsHidden()
        }

        SettingRow(
          title: L10n.text("在菜单栏短暂显示验证码"),
          detail: L10n.text("约 15 秒后自动隐藏。"),
          alignment: .center
        ) {
          Toggle(L10n.text("在菜单栏短暂显示验证码"), isOn: Binding(
            get: { state.settings.showCodeInMenuBar },
            set: { state.settings.showCodeInMenuBar = $0 }
          ))
          .toggleStyle(DrawnSwitchToggleStyle())
          .labelsHidden()
        }
      }

      SettingsSection(title: L10n.text("一键填入"), systemImage: "text.cursor") {
        SettingRow(
          title: L10n.text("在输入框旁显示填入按钮"),
          detail: L10n.text("验证码到达后 60 秒内，光标所在的输入框旁会出现「填入」按钮，点一下逐字键入。需要辅助功能权限。"),
          alignment: .center
        ) {
          Toggle(L10n.text("在输入框旁显示填入按钮"), isOn: Binding(
            get: { state.settings.quickFillEnabled },
            set: { state.setQuickFill(enabled: $0) }
          ))
          .toggleStyle(DrawnSwitchToggleStyle())
          .labelsHidden()
        }

        if state.settings.quickFillEnabled, !state.accessibilityTrusted {
          Notice(
            text: L10n.text("需要辅助功能权限。在「隐私与安全性 › 辅助功能」中打开 AutoCodeBar 后自动生效，不必重启。"),
            tone: .warn
          ) {
            Button(L10n.text("打开系统设置")) { PrivacyPaneGuide.accessibility.present() }
              .buttonStyle(SettingsActionButtonStyle())
          }
        }

        SettingRow(
          title: L10n.text("填入后自动按回车"),
          detail: L10n.text("适合输入完即提交的登录框。"),
          alignment: .center
        ) {
          Toggle(L10n.text("填入后自动按回车"), isOn: Binding(
            get: { state.settings.quickFillPressesReturn },
            set: { state.settings.quickFillPressesReturn = $0 }
          ))
          .toggleStyle(DrawnSwitchToggleStyle())
          .labelsHidden()
          .disabled(!state.settings.quickFillEnabled)
        }
      }

      SettingsSection(title: L10n.text("软件更新"), systemImage: "arrow.triangle.2.circlepath") {
        SettingRow(
          title: L10n.text("自动检查更新"),
          detail: L10n.text("每天检查一次，由 Sparkle 安全下载并安装。"),
          alignment: .center
        ) {
          Toggle(L10n.text("自动检查更新"), isOn: Binding(
            get: { state.updater.automaticallyChecksForUpdates },
            set: { state.updater.automaticallyChecksForUpdates = $0 }
          ))
          .toggleStyle(DrawnSwitchToggleStyle())
          .labelsHidden()
        }

        SettingRow(
          title: L10n.text("当前版本"),
          detail: AppVersion.short + " (" + AppVersion.build + ")",
          alignment: .center
        ) {
          Button(L10n.text("检查更新…")) { state.updater.checkForUpdates() }
            .buttonStyle(SettingsActionButtonStyle())
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
            .buttonStyle(SettingsActionButtonStyle())
        }
      }
    }
    .onAppear {
      launchAtLogin = LaunchAtLogin.isEnabled
    }
  }
}
