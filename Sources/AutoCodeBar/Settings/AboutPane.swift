import AppKit
import SwiftUI

import AutoCodeBarCore

/// 应用包里的版本号。直接跑 SwiftPM 产物时没有 Info.plist，给一个占位。
enum AppVersion {
  static var short: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.0"
  }

  static var build: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
  }
}

struct AboutPane: View {
  let state: AppState

  private var versionText: String {
    L10n.format("版本 %@ (%@)", AppVersion.short, AppVersion.build)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      HStack(spacing: 14) {
        Image(nsImage: NSApp.applicationIconImage ?? NSImage())
          .resizable()
          .interpolation(.high)
          .frame(width: 44, height: 44)
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

        VStack(alignment: .leading, spacing: 6) {
          Text(verbatim: "AutoCodeBar")
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(Theme.ink)
          HStack(spacing: 8) {
            StatusPill(text: versionText, tone: .neutral)
            Button(L10n.text("检查更新…")) { state.updater.checkForUpdates() }
              .buttonStyle(SettingsActionButtonStyle())
              .disabled(!state.updater.canCheckForUpdates)
          }
        }
      }

      SettingsSection(title: L10n.text("AutoCodeBar 做什么"), systemImage: "info.circle", spacing: 10) {
        Text(L10n.text("本机「信息」或「邮件」收到验证码时，AutoCodeBar 自动把它复制到剪贴板，并在菜单栏与通知里提醒你。所有识别都在本机完成，不连接任何服务器。"))
          .font(Theme.body)
          .foregroundStyle(Theme.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: 500, alignment: .leading)

        Text(L10n.text("历史仅保存在内存中，最多 20 条，退出应用后清除。验证码写入剪贴板时会标记为机密内容，支持该标记的剪贴板管理器不会保存它。"))
          .font(Theme.body)
          .foregroundStyle(Theme.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: 500, alignment: .leading)
      }

      SettingsSection(title: L10n.text("链接"), systemImage: "link") {
        SettingRow(title: L10n.text("源码与问题反馈"), detail: "GitHub", alignment: .center) {
          // 箭头说明这一下会离开应用；一整列都叫「打开」，旁白得听见打开的是哪个。
          Button {
            AppLinks.open(AppLinks.github)
          } label: {
            Label(L10n.text("打开"), systemImage: "arrow.up.right")
          }
          .buttonStyle(SettingsActionButtonStyle())
          .accessibilityLabel(L10n.text("源码与问题反馈"))
        }

        SettingRow(title: L10n.text("作者"), detail: "X · @zerah_eth", alignment: .center) {
          Button {
            AppLinks.open(AppLinks.x)
          } label: {
            Label(L10n.text("打开"), systemImage: "arrow.up.right")
          }
          .buttonStyle(SettingsActionButtonStyle())
          .accessibilityLabel(Text(verbatim: "X · @zerah_eth"))
        }
      }
    }
  }
}
