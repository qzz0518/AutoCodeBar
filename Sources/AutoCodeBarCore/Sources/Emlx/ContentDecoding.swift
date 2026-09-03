import Foundation

/// MIME 内容传输编码与字符集解码。
public enum ContentDecoding {
  /// quoted-printable 解码，直接操作字节。
  public static func decodeQuotedPrintable(_ data: Data) -> Data {
    var output = [UInt8]()
    output.reserveCapacity(data.count)
    let bytes = [UInt8](data)
    var index = 0

    while index < bytes.count {
      let byte = bytes[index]
      if byte == UInt8(ascii: "="), index + 1 < bytes.count {
        let first = bytes[index + 1]
        if first == UInt8(ascii: "\n") {
          index += 2
          continue
        }
        if first == UInt8(ascii: "\r"), index + 2 < bytes.count, bytes[index + 2] == UInt8(ascii: "\n") {
          index += 3
          continue
        }
        if index + 2 < bytes.count, let value = hexValue(first, bytes[index + 2]) {
          output.append(value)
          index += 3
          continue
        }
      }
      output.append(byte)
      index += 1
    }

    return Data(output)
  }

  /// base64 解码，先剔除空白。
  public static func decodeBase64(_ data: Data) -> Data? {
    let filtered = data.filter { $0 != 0x0A && $0 != 0x0D && $0 != 0x20 && $0 != 0x09 }
    guard !filtered.isEmpty else {
      return Data()
    }
    return Data(base64Encoded: Data(filtered), options: [.ignoreUnknownCharacters])
  }

  public static func hexValue(_ first: UInt8, _ second: UInt8) -> UInt8? {
    guard let high = nibble(first), let low = nibble(second) else {
      return nil
    }
    return high << 4 | low
  }

  public static func nibble(_ byte: UInt8) -> UInt8? {
    switch byte {
    case UInt8(ascii: "0")...UInt8(ascii: "9"):
      return byte - UInt8(ascii: "0")
    case UInt8(ascii: "a")...UInt8(ascii: "f"):
      return byte - UInt8(ascii: "a") + 10
    case UInt8(ascii: "A")...UInt8(ascii: "F"):
      return byte - UInt8(ascii: "A") + 10
    default:
      return nil
    }
  }

  /// IANA charset 名 → `String.Encoding`。
  public static func encoding(for charset: String?) -> String.Encoding {
    guard let charset else {
      return .utf8
    }
    let name = charset.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if name.isEmpty || name == "utf-8" || name == "utf8" {
      return .utf8
    }
    let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
    guard cfEncoding != kCFStringEncodingInvalidId else {
      return .utf8
    }
    return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
  }

  /// 按 charset 解码；失败回落 UTF-8，再回落 Latin-1。
  public static func string(from data: Data, charset: String?) -> String {
    let encoding = self.encoding(for: charset)
    if let text = String(data: data, encoding: encoding) {
      return text
    }
    if let text = String(data: data, encoding: .utf8) {
      return text
    }
    return String(data: data, encoding: .isoLatin1) ?? ""
  }

  /// 头部按 Latin-1 解码（保留原始字节，RFC 2047 之后再处理）。
  public static func latin1(_ data: Data) -> String {
    String(data: data, encoding: .isoLatin1) ?? ""
  }

  /// 部分邮件在头部直接放 8bit UTF-8。若 Latin-1 结果的原始字节是合法 UTF-8，则按 UTF-8 重新解释。
  public static func repairLatin1Mojibake(_ text: String) -> String {
    guard text.unicodeScalars.contains(where: { $0.value > 0x7F }) else {
      return text
    }
    guard let data = text.data(using: .isoLatin1),
          let repaired = String(data: data, encoding: .utf8),
          repaired != text else {
      return text
    }
    return repaired
  }
}
