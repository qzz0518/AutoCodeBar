import Foundation

/// 按验证码去重；不区分来源（同一条短信可能同时出现在多个数据库里）。
public final class Deduplicator {
  private let window: TimeInterval
  private let now: () -> Date
  private var seen: [String: Date] = [:]

  public init(window: TimeInterval = 300, now: @escaping () -> Date = Date.init) {
    self.window = window
    self.now = now
  }

  /// 首次出现返回 true；窗口内重复返回 false。
  public func accept(_ code: String) -> Bool {
    let current = now()
    prune(at: current)
    let key = code.uppercased()
    if seen[key] != nil {
      return false
    }
    seen[key] = current
    return true
  }

  public func reset() {
    seen.removeAll()
  }

  private func prune(at date: Date) {
    seen = seen.filter { date.timeIntervalSince($0.value) < window }
  }
}
