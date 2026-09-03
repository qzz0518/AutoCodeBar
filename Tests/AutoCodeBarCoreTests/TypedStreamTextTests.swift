import Foundation
import Testing

@testable import AutoCodeBarCore

/// 通过 Objective-C 运行时调用已弃用的 NSArchiver，避免编译期 deprecation 警告。
private func typedStreamData(for text: String) -> Data? {
  guard let archiverClass = NSClassFromString("NSArchiver") as? NSObject.Type else {
    return nil
  }
  let selector = NSSelectorFromString("archivedDataWithRootObject:")
  guard archiverClass.responds(to: selector) else {
    return nil
  }
  guard let result = archiverClass.perform(selector, with: NSAttributedString(string: text)) else {
    return nil
  }
  return result.takeUnretainedValue() as? Data
}

@Suite("TypedStreamText")
struct TypedStreamTextTests {
  @Test("ASCII 短串（1 字节长度）")
  func asciiFixture() throws {
    let data = try #require(typedStreamData(for: "Hello 482913"))
    #expect(TypedStreamText.string(from: data) == "Hello 482913")
  }

  @Test("CJK 长串（0x81 两字节长度）")
  func cjkFixture() throws {
    let text = String(repeating: "验证码", count: 50)
    let data = try #require(typedStreamData(for: text))
    #expect(data.count > 128)
    #expect(TypedStreamText.string(from: data) == text)
  }

  @Test("手工拼接的 0x82 四字节长度")
  func fourByteLength() {
    let payload = Array("【京东】验证码 183920".utf8)
    var bytes: [UInt8] = Array("\u{04}\u{0b}streamtyped".utf8)
    bytes += [0x81, 0xE8, 0x03, 0x84, 0x01, 0x40]
    bytes += Array("NSString".utf8)
    bytes += [0x01, 0x95, 0x84, 0x01, 0x2B, 0x82]
    let length = UInt32(payload.count)
    bytes += [
      UInt8(length & 0xFF),
      UInt8((length >> 8) & 0xFF),
      UInt8((length >> 16) & 0xFF),
      UInt8((length >> 24) & 0xFF)
    ]
    bytes += payload
    #expect(TypedStreamText.string(from: Data(bytes)) == "【京东】验证码 183920")
  }

  @Test("截断与错误数据返回 nil")
  func truncated() throws {
    #expect(TypedStreamText.string(from: nil) == nil)
    #expect(TypedStreamText.string(from: Data()) == nil)
    #expect(TypedStreamText.string(from: Data([0x01, 0x02, 0x03])) == nil)
    #expect(TypedStreamText.string(from: Data("not a typedstream at all".utf8)) == nil)

    let full = try #require(typedStreamData(for: "Hello 482913"))
    for count in 0..<full.count {
      _ = TypedStreamText.string(from: full.prefix(count))
    }
    #expect(TypedStreamText.string(from: full.prefix(full.count - 40)) == nil)
  }
}
