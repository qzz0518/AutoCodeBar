import Foundation

/// 系统通知数据库 `record.data`（二进制 plist）解析结果。
public struct NotificationRecord: Equatable {
  public let title: String?
  public let subtitle: String?
  public let body: String?
  public let bundleIdentifier: String?
  /// `req` 外层 `date`（Cocoa 参考日期起的秒数）。
  public let date: Date?

  public init(title: String?, subtitle: String?, body: String?, bundleIdentifier: String?, date: Date?) {
    self.title = title
    self.subtitle = subtitle
    self.body = body
    self.bundleIdentifier = bundleIdentifier
    self.date = date
  }

  /// 文本 = [标题, 副标题, 正文] 去空后以换行连接。
  public var text: String {
    [title, subtitle, body]
      .compactMap { $0 }
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
  }

  /// 不是 plist 一律返回 nil，不退化成乱码文本。
  public static func parse(_ data: Data?) -> NotificationRecord? {
    guard let data, !data.isEmpty else {
      return nil
    }
    guard let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
          let root = object as? [String: Any] else {
      return nil
    }

    let request = root["req"] as? [String: Any] ?? [:]
    let title = string(request["titl"])
    let subtitle = string(request["subt"])
    let body = string(request["body"])
    let bundleIdentifier = string(root["app"])
    var date: Date?
    if let seconds = (root["date"] as? NSNumber)?.doubleValue, seconds > 0 {
      date = Date(timeIntervalSinceReferenceDate: seconds)
    }

    if title == nil, subtitle == nil, body == nil {
      return nil
    }

    return NotificationRecord(
      title: title,
      subtitle: subtitle,
      body: body,
      bundleIdentifier: bundleIdentifier,
      date: date
    )
  }

  private static func string(_ value: Any?) -> String? {
    guard let text = value as? String else {
      return nil
    }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
