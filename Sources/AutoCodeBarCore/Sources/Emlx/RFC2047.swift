import Foundation

/// RFC 2047 编码字头解码。
public enum RFC2047 {
  private static let regex = try? NSRegularExpression(
    pattern: "=\\?([^?]+)\\?([bBqQ])\\?([^?]*)\\?="
  )

  public static func decode(_ value: String) -> String {
    guard let regex else {
      return value
    }
    let ns = value as NSString
    let matches = regex.matches(in: value, range: NSRange(location: 0, length: ns.length))
    guard !matches.isEmpty else {
      return value
    }

    var result = ""
    var cursor = 0
    var previousWasEncoded = false

    for match in matches {
      let gap = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
      // 相邻编码字之间的空白按 RFC 2047 剔除。
      if previousWasEncoded, gap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        // 丢弃
      } else {
        result += gap
      }

      let charset = ns.substring(with: match.range(at: 1))
      let encoding = ns.substring(with: match.range(at: 2)).lowercased()
      let payload = ns.substring(with: match.range(at: 3))

      if let decoded = decodeWord(payload: payload, encoding: encoding, charset: charset) {
        result += decoded
        previousWasEncoded = true
      } else {
        result += ns.substring(with: match.range)
        previousWasEncoded = false
      }
      cursor = match.range.location + match.range.length
    }

    if cursor < ns.length {
      result += ns.substring(from: cursor)
    }
    return result
  }

  private static func decodeWord(payload: String, encoding: String, charset: String) -> String? {
    let data: Data?
    if encoding == "b" {
      data = Data(base64Encoded: payload, options: [.ignoreUnknownCharacters])
    } else {
      let replaced = payload.replacingOccurrences(of: "_", with: " ")
      guard let raw = replaced.data(using: .isoLatin1) ?? replaced.data(using: .utf8) else {
        return nil
      }
      data = ContentDecoding.decodeQuotedPrintable(raw)
    }
    guard let data else {
      return nil
    }
    return ContentDecoding.string(from: data, charset: charset)
  }
}
