import Foundation

/// 展开折行后的 MIME 头部。
public struct MIMEHeaders {
  public let raw: String

  public init(raw: String) {
    self.raw = raw
  }

  /// 大小写不敏感取值；同名多次取第一个。
  public func value(_ name: String) -> String? {
    let target = name.lowercased() + ":"
    for line in raw.split(separator: "\n", omittingEmptySubsequences: false) {
      let text = String(line)
      guard text.lowercased().hasPrefix(target) else {
        continue
      }
      return String(text.dropFirst(target.count)).trimmingCharacters(in: .whitespaces)
    }
    return nil
  }

  public var contentType: MIMEContentType {
    MIMEContentType(header: value("Content-Type"))
  }

  public var transferEncoding: String {
    (value("Content-Transfer-Encoding") ?? "7bit").lowercased().trimmingCharacters(in: .whitespaces)
  }
}

/// `Content-Type` 的 type/subtype 与参数。
public struct MIMEContentType {
  public let type: String
  public let subtype: String
  public let parameters: [String: String]

  public init(header: String?) {
    guard let header, !header.isEmpty else {
      type = "text"
      subtype = "plain"
      parameters = [:]
      return
    }

    var segments = header.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }
    let full = segments.isEmpty ? "text/plain" : segments.removeFirst()
    let pieces = full.split(separator: "/", maxSplits: 1).map(String.init)
    type = (pieces.first ?? "text").lowercased()
    subtype = (pieces.count > 1 ? pieces[1] : "plain").lowercased()

    var params: [String: String] = [:]
    for segment in segments {
      guard let separator = segment.firstIndex(of: "=") else {
        continue
      }
      let key = String(segment[segment.startIndex..<separator])
        .trimmingCharacters(in: .whitespaces)
        .lowercased()
      var value = String(segment[segment.index(after: separator)...])
        .trimmingCharacters(in: .whitespaces)
      if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
        value = String(value.dropFirst().dropLast())
      }
      params[key] = value
    }
    parameters = params
  }

  public var charset: String? { parameters["charset"] }
  public var boundary: String? { parameters["boundary"] }
}

/// 解析后的邮件。
public struct MIMEMessage {
  public let headers: MIMEHeaders
  public let subject: String?
  public let fromDisplayName: String?
  public let fromAddress: String?
  public let date: Date?
  public let bodyText: String

  public static let bodyLimit = 20_000

  public static func parse(_ data: Data) -> MIMEMessage {
    let split = MIMEMessage.splitHeadersAndBody(data)
    let headers = MIMEHeaders(raw: MIMEMessage.unfold(ContentDecoding.latin1(split.headers)))

    let subject = headers.value("Subject").map(RFC2047.decode).map(ContentDecoding.repairLatin1Mojibake)
    let fromRaw = headers.value("From").map(RFC2047.decode).map(ContentDecoding.repairLatin1Mojibake)
    let from = MIMEMessage.parseAddress(fromRaw)
    let date = headers.value("Date").flatMap(MIMEMessage.parseDate)

    let leaves = MIMEMessage.textParts(headers: headers, body: split.body, depth: 0)
    let plain = leaves.filter { $0.subtype == "plain" }
    let chosen = plain.isEmpty ? leaves.filter { $0.subtype == "html" } : plain
    var body = chosen.map(\.text).joined(separator: "\n")
    if body.count > bodyLimit {
      body = String(body.prefix(bodyLimit))
    }

    return MIMEMessage(
      headers: headers,
      subject: subject,
      fromDisplayName: from.display,
      fromAddress: from.address,
      date: date,
      bodyText: body
    )
  }

  // MARK: - 头 / 体切分

  static func splitHeadersAndBody(_ data: Data) -> (headers: Data, body: Data) {
    let bytes = [UInt8](data)
    var index = 0
    while index < bytes.count {
      if bytes[index] == 0x0A {
        if index + 1 < bytes.count, bytes[index + 1] == 0x0A {
          return (Data(bytes[0..<index]), Data(bytes[(index + 2)...]))
        }
        if index + 2 < bytes.count, bytes[index + 1] == 0x0D, bytes[index + 2] == 0x0A {
          return (Data(bytes[0..<index]), Data(bytes[(index + 3)...]))
        }
      }
      index += 1
    }
    return (data, Data())
  }

  static func unfold(_ headers: String) -> String {
    headers
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\n[ \t]+", with: " ", options: .regularExpression)
  }

  // MARK: - 正文

  struct TextLeaf {
    let subtype: String
    let text: String
  }

  static func textParts(headers: MIMEHeaders, body: Data, depth: Int) -> [TextLeaf] {
    guard depth < 12 else {
      return []
    }
    let contentType = headers.contentType

    if contentType.type == "multipart", let boundary = contentType.boundary, !boundary.isEmpty {
      let chunks = splitMultipart(body: body, boundary: boundary)
      let groups = chunks.map { chunk -> [TextLeaf] in
        let inner = splitHeadersAndBody(chunk)
        let innerHeaders = MIMEHeaders(raw: unfold(ContentDecoding.latin1(inner.headers)))
        return textParts(headers: innerHeaders, body: inner.body, depth: depth + 1)
      }
      if contentType.subtype == "alternative" {
        if let plainGroup = groups.first(where: { group in group.contains { $0.subtype == "plain" } }) {
          return plainGroup
        }
        return groups.first(where: { !$0.isEmpty }) ?? []
      }
      return groups.flatMap { $0 }
    }

    guard contentType.type == "text" else {
      return []
    }

    let decoded = decodeBody(body, transferEncoding: headers.transferEncoding)
    let text = ContentDecoding.string(from: decoded, charset: contentType.charset)
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return []
    }
    if contentType.subtype == "html" {
      return [TextLeaf(subtype: "html", text: HTMLText.plainText(from: text))]
    }
    return [TextLeaf(subtype: "plain", text: text)]
  }

  static func decodeBody(_ data: Data, transferEncoding: String) -> Data {
    switch transferEncoding {
    case "quoted-printable":
      return ContentDecoding.decodeQuotedPrintable(data)
    case "base64":
      return ContentDecoding.decodeBase64(data) ?? Data()
    default:
      return data
    }
  }

  /// 按 `--boundary` 行切分 multipart 主体。
  static func splitMultipart(body: Data, boundary: String) -> [Data] {
    let bytes = [UInt8](body)
    let delimiter = Array("--\(boundary)".utf8)
    guard !delimiter.isEmpty, bytes.count >= delimiter.count else {
      return []
    }

    var markers: [Int] = []
    var index = 0
    let limit = bytes.count - delimiter.count
    while index <= limit {
      var matched = true
      for offset in 0..<delimiter.count where bytes[index + offset] != delimiter[offset] {
        matched = false
        break
      }
      if matched, index == 0 || bytes[index - 1] == 0x0A {
        markers.append(index)
        index += delimiter.count
      } else {
        index += 1
      }
    }
    guard markers.count >= 2 else {
      return []
    }

    var parts: [Data] = []
    for position in 0..<(markers.count - 1) {
      let markerStart = markers[position]
      let afterDelimiter = markerStart + delimiter.count
      if afterDelimiter + 1 < bytes.count,
         bytes[afterDelimiter] == UInt8(ascii: "-"),
         bytes[afterDelimiter + 1] == UInt8(ascii: "-") {
        break
      }
      guard var start = bytes[afterDelimiter...].firstIndex(of: 0x0A) else {
        break
      }
      start += 1
      var end = markers[position + 1]
      if end > start, bytes[end - 1] == 0x0A {
        end -= 1
      }
      if end > start, bytes[end - 1] == 0x0D {
        end -= 1
      }
      guard end > start else {
        continue
      }
      parts.append(Data(bytes[start..<end]))
    }
    return parts
  }

  // MARK: - 头部字段

  static func parseAddress(_ raw: String?) -> (display: String?, address: String?) {
    guard let raw, !raw.isEmpty else {
      return (nil, nil)
    }
    if let open = raw.lastIndex(of: "<"), let close = raw[open...].firstIndex(of: ">") {
      let address = String(raw[raw.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
      var display = String(raw[raw.startIndex..<open]).trimmingCharacters(in: .whitespaces)
      if display.hasPrefix("\""), display.hasSuffix("\""), display.count >= 2 {
        display = String(display.dropFirst().dropLast())
      }
      return (display.isEmpty ? nil : display, address.isEmpty ? nil : address)
    }
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    return (nil, trimmed.isEmpty ? nil : trimmed)
  }

  private static let dateFormats = [
    "EEE, d MMM yyyy HH:mm:ss Z",
    "d MMM yyyy HH:mm:ss Z",
    "EEE, d MMM yyyy HH:mm Z",
    "d MMM yyyy HH:mm Z"
  ]

  static func parseDate(_ raw: String) -> Date? {
    let cleaned = raw.replacingOccurrences(of: "\\s*\\([^)]*\\)\\s*$", with: "", options: .regularExpression)
      .trimmingCharacters(in: .whitespaces)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    for format in dateFormats {
      formatter.dateFormat = format
      if let date = formatter.date(from: cleaned) {
        return date
      }
    }
    return nil
  }
}
