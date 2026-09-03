import Foundation

/// 单个来源的运行状态。
public enum SourceStatus: Equatable, Sendable {
  case off
  case starting
  case running
  case needsFullDiskAccess
  case unavailable(String)
  case failed(String)

  /// 状态文案。
  public var text: String {
    switch self {
    case .off: return L10n.text("已关闭", table: "Core")
    case .starting: return L10n.text("启动中…", table: "Core")
    case .running: return L10n.text("正在监听", table: "Core")
    case .needsFullDiskAccess: return L10n.text("需要完整磁盘访问", table: "Core")
    case .unavailable(let message): return message
    case .failed(let message): return message
    }
  }

  public var isRunning: Bool {
    self == .running
  }

  public var isBlocking: Bool {
    switch self {
    case .needsFullDiskAccess, .unavailable, .failed: return true
    case .off, .starting, .running: return false
    }
  }
}
