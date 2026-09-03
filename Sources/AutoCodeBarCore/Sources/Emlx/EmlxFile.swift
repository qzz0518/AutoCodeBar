import Foundation

/// `.emlx` 文件：首行字节数 + RFC 5322 报文 + 尾部 XML plist。
public struct EmlxFile {
  public let message: Data
  public let plist: [String: Any]?

  public init(message: Data, plist: [String: Any]?) {
    self.message = message
    self.plist = plist
  }

  /// plist 里的 `date-received`（Unix 秒）。
  public var dateReceived: Date? {
    guard let value = plist?["date-received"] else {
      return nil
    }
    if let number = value as? NSNumber {
      return Date(timeIntervalSince1970: number.doubleValue)
    }
    if let text = value as? String, let seconds = Double(text) {
      return Date(timeIntervalSince1970: seconds)
    }
    return nil
  }

  /// 按字节切分，绝不把整个文件转成 String。
  public static func parse(_ data: Data) -> EmlxFile? {
    guard !data.isEmpty else {
      return nil
    }
    let bytes = [UInt8](data)
    guard let newline = bytes.firstIndex(of: 0x0A) else {
      return EmlxFile(message: data, plist: nil)
    }

    let headerLine = String(decoding: bytes[0..<newline], as: UTF8.self)
      .trimmingCharacters(in: .whitespaces)
    guard let count = Int(headerLine), count > 0 else {
      return EmlxFile(message: data, plist: nil)
    }

    let start = newline + 1
    guard start <= bytes.count else {
      return EmlxFile(message: data, plist: nil)
    }
    let end = min(start + count, bytes.count)
    let message = Data(bytes[start..<end])

    var plist: [String: Any]?
    if end < bytes.count {
      let trailer = Data(bytes[end..<bytes.count])
      if let object = try? PropertyListSerialization.propertyList(from: trailer, format: nil),
         let dict = object as? [String: Any] {
        plist = dict
      }
    }

    return EmlxFile(message: message, plist: plist)
  }
}
