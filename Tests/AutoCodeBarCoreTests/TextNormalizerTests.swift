import Foundation
import Testing

@testable import AutoCodeBarCore

@Suite("TextNormalizer")
struct TextNormalizerTests {
  @Test("全角字母数字转半角")
  func fullwidth() {
    #expect(TextNormalizer.normalize("验证码：１２３４５６") == "验证码:123456")
    #expect(TextNormalizer.normalize("ＡＢＣ１２３") == "ABC123")
  }

  @Test("零宽字符被剔除")
  func zeroWidth() {
    let input = "验\u{200B}证\u{200C}码\u{FEFF} 1\u{200D}23456"
    #expect(TextNormalizer.normalize(input) == "验证码 123456")
  }

  @Test("URL 与邮箱被遮罩")
  func masking() {
    let text = TextNormalizer.normalize("code 552901 see https://example.com/a?b=1 or www.example.com")
    #expect(!text.contains("example.com"))
    #expect(text.contains("552901"))

    let mail = TextNormalizer.normalize("contact me@example.com for 123456")
    #expect(!mail.contains("@"))
    #expect(mail.contains("123456"))
  }

  @Test("水平空白折叠、换行保留")
  func whitespace() {
    let text = TextNormalizer.normalize("a\t\t b\r\n\r\n\r\nc   d\n   e")
    #expect(text == "a b\nc d\ne")
  }

  @Test("单行预览截断")
  func singleLine() {
    let long = String(repeating: "验证码", count: 40)
    let preview = TextNormalizer.singleLine(long)
    #expect(preview.count == 81)
    #expect(preview.hasSuffix("…"))
    #expect(TextNormalizer.singleLine("a\nb") == "a b")
  }
}
