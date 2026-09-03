import Foundation

/// 文本规范化：全角转半角、剔除零宽字符、遮罩 URL/邮箱、折叠空白但保留换行。
public enum TextNormalizer {
  private static let zeroWidth: Set<Unicode.Scalar> = [
    "\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}"
  ]

  private static let urlRegex = try? NSRegularExpression(
    pattern: "(?i)(?:https?://\\S+|www\\.\\S+)"
  )
  private static let emailRegex = try? NSRegularExpression(
    pattern: "\\S+@\\S+\\.\\S+"
  )
  private static let horizontalSpaceRegex = try? NSRegularExpression(
    pattern: "[^\\S\\n]+"
  )
  private static let newlineRunRegex = try? NSRegularExpression(
    pattern: " ?\\n[ \\n]*"
  )

  /// 完整规范化流程。
  public static func normalize(_ input: String) -> String {
    var text = input.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? input

    if text.unicodeScalars.contains(where: { zeroWidth.contains($0) }) {
      text = String(String.UnicodeScalarView(text.unicodeScalars.filter { !zeroWidth.contains($0) }))
    }

    text = text.replacingOccurrences(of: "\r\n", with: "\n")
    text = text.replacingOccurrences(of: "\r", with: "\n")

    text = replaceAll(urlRegex, in: text, with: " ")
    text = replaceAll(emailRegex, in: text, with: " ")
    text = replaceAll(horizontalSpaceRegex, in: text, with: " ")
    text = replaceAll(newlineRunRegex, in: text, with: "\n")

    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// 仅对关键词做同样的全角/零宽处理，保证与正文可比。
  public static func normalizeKeyword(_ input: String) -> String {
    var text = input.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? input
    text = String(String.UnicodeScalarView(text.unicodeScalars.filter { !zeroWidth.contains($0) }))
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// 折叠为单行并截断，供预览使用。
  public static func singleLine(_ input: String, limit: Int = 80) -> String {
    let flattened = input
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "  ", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard flattened.count > limit else {
      return flattened
    }
    return String(flattened.prefix(limit)) + "…"
  }

  private static func replaceAll(_ regex: NSRegularExpression?, in text: String, with template: String) -> String {
    guard let regex else {
      return text
    }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
  }
}
