import Foundation
import Testing

@testable import AutoCodeBarCore

@Suite("EmlxFile")
struct EmlxFileTests {
  private func makeFile(message: String, trailer: String?, pad: String = "       ") -> Data {
    let body = Data(message.utf8)
    var data = Data("\(body.count)\(pad)\n".utf8)
    data.append(body)
    if let trailer {
      data.append(Data(trailer.utf8))
    }
    return data
  }

  private let plistTrailer = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    \t<key>date-received</key>
    \t<integer>1763575952</integer>
    \t<key>flags</key>
    \t<integer>8590195713</integer>
    </dict>
    </plist>
    """

  @Test("字节数行带尾随空格")
  func trailingSpacesInCountLine() throws {
    let message = "Subject: Hi\n\nbody 482913"
    let file = try #require(EmlxFile.parse(makeFile(message: message, trailer: plistTrailer)))
    #expect(String(decoding: file.message, as: UTF8.self) == message)
  }

  @Test("尾部 plist 的 date-received")
  func dateReceived() throws {
    let file = try #require(EmlxFile.parse(makeFile(message: "Subject: Hi\n\nbody", trailer: plistTrailer)))
    #expect(file.dateReceived == Date(timeIntervalSince1970: 1_763_575_952))
  }

  @Test("plist 损坏时报文仍可解析")
  func brokenPlist() throws {
    let message = "Subject: Hi\n\nbody 482913"
    let file = try #require(EmlxFile.parse(makeFile(message: message, trailer: "<<<not a plist>>>")))
    #expect(String(decoding: file.message, as: UTF8.self) == message)
    #expect(file.plist == nil)
    #expect(file.dateReceived == nil)
  }

  @Test("字节数按字节计（含多字节字符）")
  func byteAccurate() throws {
    let message = "Subject: 验证码\n\n您的验证码是 482913"
    let file = try #require(EmlxFile.parse(makeFile(message: message, trailer: plistTrailer, pad: "")))
    #expect(String(decoding: file.message, as: UTF8.self) == message)
  }

  @Test("没有字节数行时整体作为报文")
  func withoutCountLine() throws {
    let raw = Data("Subject: Hi\n\nbody".utf8)
    let file = try #require(EmlxFile.parse(raw))
    #expect(file.message == raw)
  }
}
