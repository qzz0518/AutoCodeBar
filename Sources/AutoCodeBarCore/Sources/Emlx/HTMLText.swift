import Foundation

/// HTML → 纯文本。保留换行（抽取算法依赖行结构）。
public enum HTMLText {
  private static let dropRegexes: [NSRegularExpression] = [
    "(?is)<style[^>]*>.*?</style>",
    "(?is)<script[^>]*>.*?</script>",
    "(?s)<!--.*?-->"
  ].compactMap { try? NSRegularExpression(pattern: $0) }

  private static let breakRegex = try? NSRegularExpression(
    pattern: "(?i)<br\\s*/?>|</p>|</div>|</li>|</tr>|</h[1-6]>|<p[^>]*>|<div[^>]*>|<tr[^>]*>|<li[^>]*>"
  )
  private static let tabRegex = try? NSRegularExpression(pattern: "(?i)</td>")
  private static let tagRegex = try? NSRegularExpression(pattern: "(?s)<[^>]+>")
  private static let spaceRegex = try? NSRegularExpression(pattern: "[^\\S\\n\\t]+")
  private static let newlineRegex = try? NSRegularExpression(pattern: "[ \\t]?\\n[ \\t\\n]*")

  public static func plainText(from html: String) -> String {
    var text = html
    for regex in dropRegexes {
      text = replace(regex, in: text, with: "")
    }
    text = replace(tabRegex, in: text, with: "\t")
    text = replace(breakRegex, in: text, with: "\n")
    text = replace(tagRegex, in: text, with: "")
    text = decodeEntities(text)
    text = replace(spaceRegex, in: text, with: " ")
    text = replace(newlineRegex, in: text, with: "\n")
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static let namedEntities: [String: String] = [
    "&nbsp;": " ",
    "&amp;": "&",
    "&lt;": "<",
    "&gt;": ">",
    "&quot;": "\"",
    "&apos;": "'",
    "&#39;": "'"
  ]

  private static let numericRegex = try? NSRegularExpression(pattern: "&#(x[0-9A-Fa-f]+|[0-9]+);")

  public static func decodeEntities(_ input: String) -> String {
    var text = input
    for (entity, replacement) in namedEntities {
      if text.contains(entity) {
        text = text.replacingOccurrences(of: entity, with: replacement)
      }
    }
    guard let numericRegex else {
      return text
    }
    let ns = text as NSString
    let matches = numericRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
    guard !matches.isEmpty else {
      return text
    }
    var result = ""
    var cursor = 0
    for match in matches {
      result += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
      let token = ns.substring(with: match.range(at: 1))
      let value: UInt32?
      if token.lowercased().hasPrefix("x") {
        value = UInt32(token.dropFirst(), radix: 16)
      } else {
        value = UInt32(token)
      }
      if let value, let scalar = Unicode.Scalar(value) {
        result.unicodeScalars.append(scalar)
      } else {
        result += ns.substring(with: match.range)
      }
      cursor = match.range.location + match.range.length
    }
    if cursor < ns.length {
      result += ns.substring(from: cursor)
    }
    return result
  }

  private static func replace(_ regex: NSRegularExpression?, in text: String, with template: String) -> String {
    guard let regex else {
      return text
    }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.stringByReplacingMatches(
      in: text,
      range: range,
      withTemplate: NSRegularExpression.escapedTemplate(for: template)
    )
  }
}
