import SwiftUI
import UserNotifications

import AutoCodeBarCore

struct PermissionsPane: View {
  let state: AppState

  private var fdaGranted: Bool {
    state.fullDiskAccess == .granted
  }

  private var notificationGranted: Bool {
    state.notificationAuth == .authorized || state.notificationAuth == .provisional
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      SettingsSection(title: L10n.text("系统权限"), systemImage: "checkmark.shield") {
        PermissionRow(
          title: L10n.text("完整磁盘访问"),
          detail: L10n.text("读取「信息」数据库与「邮件」本地文件所必需。授权后 AutoCodeBar 自动恢复监听。"),
          granted: fdaGranted
        ) {
          Button(L10n.text("打开系统设置")) { state.openFullDiskAccessSettings() }
            .buttonStyle(SoftButtonStyle())
        }

        PermissionRow(
          title: L10n.text("通知"),
          detail: L10n.text("复制后显示横幅。"),
          granted: notificationGranted,
          grantedText: L10n.text("已允许"),
          missingText: state.notificationAuth == .denied ? L10n.text("已拒绝") : L10n.text("未开启"),
          missingTone: state.notificationAuth == .denied ? .bad : .warn
        ) {
          if state.notificationAuth == .denied {
            Button(L10n.text("打开通知设置")) { SystemSettingsLinks.openNotifications() }
              .buttonStyle(SoftButtonStyle())
          } else {
            Button(L10n.text("允许…")) { state.requestNotificationAuthorization() }
              .buttonStyle(SoftButtonStyle())
          }
        }
      }

      Notice(
        text: L10n.text("完整磁盘访问不会弹出系统授权框，需要手动把 AutoCodeBar 加入列表。若已加入仍显示未授权，请重新启动应用。"),
        tone: .info
      ) {
        Button(L10n.text("重新启动")) { Relauncher.relaunch() }
          .buttonStyle(SoftButtonStyle())
      }
    }
  }
}
