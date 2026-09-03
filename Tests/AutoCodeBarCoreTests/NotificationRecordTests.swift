import Foundation
import Testing

@testable import AutoCodeBarCore

private func bplist(_ object: [String: Any]) throws -> Data {
  try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0)
}

@Suite("NotificationRecord")
struct NotificationRecordTests {
  @Test("完整 req 字典")
  func complete() throws {
    let data = try bplist([
      "app": "com.apple.mobilesms",
      "date": 810_143_643.0,
      "req": [
        "titl": "京东",
        "subt": "验证码",
        "body": "您的验证码为 183920",
        "iden": "abc",
        "cate": "def"
      ]
    ])
    let record = try #require(NotificationRecord.parse(data))
    #expect(record.title == "京东")
    #expect(record.subtitle == "验证码")
    #expect(record.body == "您的验证码为 183920")
    #expect(record.bundleIdentifier == "com.apple.mobilesms")
    #expect(record.text == "京东\n验证码\n您的验证码为 183920")
    #expect(record.date == Date(timeIntervalSinceReferenceDate: 810_143_643.0))
  }

  @Test("缺 body 仍可解析")
  func missingBody() throws {
    let data = try bplist(["app": "com.example.app", "req": ["titl": "标题"]])
    let record = try #require(NotificationRecord.parse(data))
    #expect(record.body == nil)
    #expect(record.text == "标题")
    #expect(record.date == nil)
  }

  @Test("非 plist 数据返回 nil")
  func notAPlist() {
    #expect(NotificationRecord.parse(nil) == nil)
    #expect(NotificationRecord.parse(Data()) == nil)
    #expect(NotificationRecord.parse(Data("验证码 183920".utf8)) == nil)
    #expect(NotificationRecord.parse(Data([0x00, 0xFF, 0x10, 0x42])) == nil)
  }

  @Test("完全没有文本时返回 nil")
  func emptyRequest() throws {
    let data = try bplist(["app": "com.example.app", "req": ["iden": "x"]])
    #expect(NotificationRecord.parse(data) == nil)
  }
}
