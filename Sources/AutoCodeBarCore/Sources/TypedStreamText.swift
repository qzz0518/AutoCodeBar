import Foundation

/// 从「信息」数据库的 `attributedBody`（NSArchiver typedstream）里提取正文。
public enum TypedStreamText {
  private static let header: [UInt8] = Array("\u{04}\u{0b}streamtyped".utf8)
  private static let marker: [UInt8] = Array("NSString".utf8)

  /// 解析失败一律返回 nil，不得崩溃。
  public static func string(from data: Data?) -> String? {
    guard let data else {
      return nil
    }
    let bytes = [UInt8](data)
    guard bytes.count > header.count else {
      return nil
    }
    for index in 0..<header.count where bytes[index] != header[index] {
      return nil
    }

    guard let markerEnd = firstRange(of: marker, in: bytes, from: header.count) else {
      return nil
    }

    var cursor = markerEnd
    while cursor < bytes.count, bytes[cursor] != 0x2B {
      cursor += 1
    }
    guard cursor < bytes.count else {
      return nil
    }
    cursor += 1

    guard cursor < bytes.count else {
      return nil
    }
    let lengthMarker = bytes[cursor]
    cursor += 1

    let length: Int
    switch lengthMarker {
    case 0..<0x80:
      length = Int(lengthMarker)
    case 0x81:
      guard cursor + 2 <= bytes.count else {
        return nil
      }
      length = Int(bytes[cursor]) | (Int(bytes[cursor + 1]) << 8)
      cursor += 2
    case 0x82:
      guard cursor + 4 <= bytes.count else {
        return nil
      }
      length = Int(bytes[cursor])
        | (Int(bytes[cursor + 1]) << 8)
        | (Int(bytes[cursor + 2]) << 16)
        | (Int(bytes[cursor + 3]) << 24)
      cursor += 4
    default:
      return nil
    }

    guard length > 0, cursor + length <= bytes.count else {
      return nil
    }
    let slice = bytes[cursor..<(cursor + length)]
    let text = String(decoding: slice, as: UTF8.self)
    return text.isEmpty ? nil : text
  }

  /// 返回 `needle` 首次出现后的下标（即匹配区间的结束位置）。
  private static func firstRange(of needle: [UInt8], in haystack: [UInt8], from start: Int) -> Int? {
    guard !needle.isEmpty, haystack.count >= needle.count else {
      return nil
    }
    let limit = haystack.count - needle.count
    guard start <= limit else {
      return nil
    }
    var index = start
    while index <= limit {
      var matched = true
      for offset in 0..<needle.count where haystack[index + offset] != needle[offset] {
        matched = false
        break
      }
      if matched {
        return index + needle.count
      }
      index += 1
    }
    return nil
  }
}
