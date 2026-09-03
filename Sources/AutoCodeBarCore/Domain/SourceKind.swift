import Foundation

/// 三个受支持的数据来源。
public enum SourceKind: String, CaseIterable, Codable, Sendable {
  case messages
  case mail
  case notificationCenter

  /// 面板副标题与通知正文里使用的短名。
  public var shortName: String {
    switch self {
    case .messages: return L10n.text("短信", table: "Core")
    case .mail: return L10n.text("邮件", table: "Core")
    case .notificationCenter: return L10n.text("通知", table: "Core")
    }
  }

  /// 设置页使用的完整名称。
  public var fullName: String {
    switch self {
    case .messages: return L10n.text("短信 / iMessage", table: "Core")
    case .mail: return L10n.text("邮件", table: "Core")
    case .notificationCenter: return L10n.text("通知中心（实验）", table: "Core")
    }
  }

  /// SF Symbol 名称。
  public var symbolName: String {
    switch self {
    case .messages: return "message.fill"
    case .mail: return "envelope.fill"
    case .notificationCenter: return "bell.fill"
    }
  }

  /// 设置页的来源描述。
  public var detail: String {
    switch self {
    case .messages:
      return L10n.text("读取「信息」应用的本地数据库，覆盖转发到 Mac 的短信和 iMessage。", table: "Core")
    case .mail:
      return L10n.text("监听「邮件」应用本地存储的新邮件，支持纯文本和 HTML 邮件。", table: "Core")
    case .notificationCenter:
      return L10n.text("读取系统通知数据库，可覆盖 iPhone 镜像等其他应用的通知。系统版本更新后可能失效。", table: "Core")
    }
  }
}
