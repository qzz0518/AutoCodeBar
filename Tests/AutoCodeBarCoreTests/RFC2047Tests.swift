import Foundation
import Testing

@testable import AutoCodeBarCore

@Suite("RFC2047")
struct RFC2047Tests {
  @Test("B 编码 UTF-8")
  func base64UTF8() {
    let payload = Data("验证码通知".utf8).base64EncodedString()
    #expect(RFC2047.decode("=?utf-8?B?\(payload)?=") == "验证码通知")
  }

  @Test("Q 编码，下划线代表空格")
  func quotedPrintable() {
    #expect(RFC2047.decode("=?utf-8?Q?Your_code_is_=34=38=32?=") == "Your code is 482")
  }

  @Test("GB2312 B 编码")
  func gb2312() {
    let encoding = ContentDecoding.encoding(for: "gb2312")
    let data = "验证码".data(using: encoding)
    let payload = (data ?? Data()).base64EncodedString()
    #expect(RFC2047.decode("=?gb2312?B?\(payload)?=") == "验证码")
  }

  @Test("相邻编码字之间的空白被剔除")
  func adjacentWords() {
    let first = Data("验证".utf8).base64EncodedString()
    let second = Data("码 482913".utf8).base64EncodedString()
    #expect(RFC2047.decode("=?utf-8?B?\(first)?= =?utf-8?B?\(second)?=") == "验证码 482913")
  }

  @Test("非编码字部分原样保留")
  func mixed() {
    let payload = Data("知乎".utf8).base64EncodedString()
    #expect(RFC2047.decode("[=?utf-8?B?\(payload)?=] Login") == "[知乎] Login")
  }
}
