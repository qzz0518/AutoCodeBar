import Foundation
import Testing

@testable import AutoCodeBarCore

@Suite("MIMEMessage")
struct MIMEMessageTests {
  @Test("text/plain + quoted-printable + gb2312")
  func quotedPrintableGB2312() throws {
    let encoding = ContentDecoding.encoding(for: "gb2312")
    let bodyData = try #require("您的验证码是 482913".data(using: encoding))
    var quoted = ""
    for byte in bodyData {
      if byte < 0x80 {
        quoted.append(Character(UnicodeScalar(byte)))
      } else {
        quoted += String(format: "=%02X", byte)
      }
    }
    let raw = """
      From: 京东 <no-reply@jd.com>
      Subject: test
      Content-Type: text/plain; charset="gb2312"
      Content-Transfer-Encoding: quoted-printable

      \(quoted)
      """
    let message = MIMEMessage.parse(Data(raw.utf8))
    #expect(message.bodyText.contains("您的验证码是 482913"))
    #expect(message.fromDisplayName == "京东")
    #expect(message.fromAddress == "no-reply@jd.com")
  }

  @Test("multipart/alternative 优先 text/plain")
  func alternativePrefersPlain() {
    let raw = """
      Subject: hi
      Content-Type: multipart/alternative; boundary="B1"

      --B1
      Content-Type: text/plain; charset=utf-8

      PLAIN 482913
      --B1
      Content-Type: text/html; charset=utf-8

      <p>HTML 999999</p>
      --B1--
      """
    let message = MIMEMessage.parse(Data(raw.utf8))
    #expect(message.bodyText.contains("PLAIN 482913"))
    #expect(!message.bodyText.contains("999999"))
  }

  @Test("multipart/mixed 里的 base64 图片附件被跳过")
  func skipsBinaryAttachment() {
    let attachment = Data(repeating: 0xAB, count: 600).base64EncodedString()
    let raw = """
      Subject: hi
      Content-Type: multipart/mixed; boundary="M1"

      --M1
      Content-Type: text/plain; charset=utf-8

      验证码 482913
      --M1
      Content-Type: image/png; name="a.png"
      Content-Transfer-Encoding: base64

      \(attachment)
      --M1--
      """
    let message = MIMEMessage.parse(Data(raw.utf8))
    #expect(message.bodyText == "验证码 482913")
  }

  @Test("8bit UTF-8 中文正文")
  func eightBitUTF8() {
    let raw = """
      Subject: hi
      Content-Type: text/plain; charset=utf-8
      Content-Transfer-Encoding: 8bit

      您的验证码是 482913，五分钟内有效。
      """
    let message = MIMEMessage.parse(Data(raw.utf8))
    #expect(message.bodyText.contains("您的验证码是 482913"))
  }

  @Test("HTML-only 邮件")
  func htmlOnly() {
    let raw = """
      Subject: hi
      Content-Type: text/html; charset=utf-8

      <html><body><style>p{}</style><p>验证码</p><p>482913</p></body></html>
      """
    let message = MIMEMessage.parse(Data(raw.utf8))
    #expect(message.bodyText == "验证码\n482913")
  }

  @Test("嵌套 multipart")
  func nestedMultipart() {
    let raw = """
      Subject: hi
      Content-Type: multipart/mixed; boundary="OUT"

      --OUT
      Content-Type: multipart/alternative; boundary="IN"

      --IN
      Content-Type: text/plain; charset=utf-8

      验证码 918273
      --IN
      Content-Type: text/html; charset=utf-8

      <p>918273</p>
      --IN--
      --OUT
      Content-Type: application/pdf; name="a.pdf"
      Content-Transfer-Encoding: base64

      \(Data(repeating: 0x11, count: 120).base64EncodedString())
      --OUT--
      """
    let message = MIMEMessage.parse(Data(raw.utf8))
    #expect(message.bodyText == "验证码 918273")
  }

  @Test("折行头部与 RFC 2047 主题")
  func foldedHeaders() {
    let payload = Data("知乎登录验证码".utf8).base64EncodedString()
    let raw = """
      Subject: =?utf-8?B?\(payload)?=
      From: "Zhihu Team"
       <no-reply@zhihu.com>
      Content-Type: text/plain;
       charset=utf-8

      验证码 557201
      """
    let message = MIMEMessage.parse(Data(raw.utf8))
    #expect(message.subject == "知乎登录验证码")
    #expect(message.fromAddress == "no-reply@zhihu.com")
    #expect(message.fromDisplayName == "Zhihu Team")
    #expect(message.bodyText.contains("557201"))
  }

  @Test("Date 头解析")
  func dateHeader() throws {
    let raw = """
      Subject: hi
      Date: Wed, 19 Nov 2025 10:12:32 +0800
      Content-Type: text/plain; charset=utf-8

      验证码 482913
      """
    let message = MIMEMessage.parse(Data(raw.utf8))
    let date = try #require(message.date)
    #expect(abs(date.timeIntervalSince1970 - 1_763_518_352) < 1)
  }
}
