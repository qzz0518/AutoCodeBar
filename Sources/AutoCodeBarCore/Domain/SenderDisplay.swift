import Foundation

/// 发件人显示名推导。
public enum SenderDisplay {
  public static var unknown: String { L10n.text("未知发件人", table: "Core") }

  /// 短信：优先取正文开头 `【…】` / `[…]` 中的品牌名（≤ 12 字符）。
  public static func forMessage(text: String, handle: String?) -> String {
    if let brand = leadingBrand(in: text) {
      return brand
    }
    if let handle, !handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return handle
    }
    return unknown
  }

  /// 从正文开头提取 `【…】` 或 `[…]` 内的品牌名。
  public static func leadingBrand(in text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let opener = trimmed.first else {
      return nil
    }

    let closer: Character
    switch opener {
    case "【": closer = "】"
    case "[": closer = "]"
    default: return nil
    }

    guard let end = trimmed.firstIndex(of: closer) else {
      return nil
    }
    let inner = String(trimmed[trimmed.index(after: trimmed.startIndex)..<end])
      .trimmingCharacters(in: .whitespaces)
    guard !inner.isEmpty, inner.count <= 12 else {
      return nil
    }
    return inner
  }

  /// 通用回落。
  public static func fallback(_ candidates: String?...) -> String {
    for value in candidates {
      if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return value
      }
    }
    return unknown
  }
}
