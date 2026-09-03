import Foundation
import Testing

@testable import AutoCodeBarCore

@Suite("SenderDisplay")
struct SenderDisplayTests {
  @Test("【品牌】提取")
  func chineseBrackets() {
    #expect(SenderDisplay.forMessage(text: "【京东】验证码 183920", handle: "+8613800138000") == "京东")
  }

  @Test("[品牌] 提取")
  func asciiBrackets() {
    #expect(SenderDisplay.forMessage(text: "[TikTok] 482913 is your code", handle: nil) == "TikTok")
  }

  @Test("超过 12 字符不作为品牌")
  func lengthLimit() {
    let text = "【这是一个非常非常长的品牌名称】验证码 123456"
    #expect(SenderDisplay.forMessage(text: text, handle: "10086") == "10086")
  }

  @Test("无品牌时回落 handle，再回落未知")
  func fallbacks() {
    #expect(SenderDisplay.forMessage(text: "验证码 123456", handle: "10086") == "10086")
    #expect(SenderDisplay.forMessage(text: "验证码 123456", handle: nil) == "未知发件人")
    #expect(SenderDisplay.forMessage(text: "验证码 123456", handle: "  ") == "未知发件人")
    #expect(SenderDisplay.fallback(nil, "", "a@b.com") == "a@b.com")
    #expect(SenderDisplay.fallback(nil, nil) == "未知发件人")
  }
}
