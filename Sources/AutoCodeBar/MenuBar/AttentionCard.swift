import SwiftUI

import AutoCodeBarCore

struct AttentionCard: View {
  let state: AppState
  let openSettings: () -> Void

  private var isFailure: Bool {
    if case .failed = state.overall {
      return true
    }
    return false
  }

  private var title: String {
    switch state.overall {
    case .needsFullDiskAccess: return L10n.text("需要完整磁盘访问")
    case .failed: return L10n.text("来源启动失败")
    case .noSources: return L10n.text("未启用任何来源")
    default: return ""
    }
  }

  private var message: String {
    switch state.overall {
    case .needsFullDiskAccess:
      return L10n.text("用于读取「信息」和「邮件」的本地数据，授权后自动恢复。")
    case .failed(let failures):
      return failures
        .map { L10n.format("%@：%@", $0.kind.shortName, $0.reason) }
        .joined(separator: "\n")
    case .noSources:
      return L10n.text("到「设置 › 来源」开启短信或邮件。")
    default:
      return ""
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(isFailure ? Theme.danger : Theme.warning)
          .font(.system(size: 12))
        Text(title)
          .font(.system(size: 12, weight: .semibold))
      }

      Text(message)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 10) {
        switch state.overall {
        case .needsFullDiskAccess:
          Button(L10n.text("打开系统设置")) { state.openFullDiskAccessSettings() }
            .controlSize(.small)
          if state.showRelaunchHint {
            Button(L10n.text("重新启动应用")) { Relauncher.relaunch() }
              .buttonStyle(.plain)
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
          }
        case .failed:
          Button(L10n.text("重试")) { state.retryFailedSources() }
            .controlSize(.small)
          Button(L10n.text("打开设置")) { openSettings() }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        case .noSources:
          Button(L10n.text("打开设置")) { openSettings() }
            .controlSize(.small)
        default:
          EmptyView()
        }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(isFailure ? Theme.dangerSoft : Theme.warningSoft)
    )
    .padding(.horizontal, 12)
    .padding(.top, 10)
  }
}
