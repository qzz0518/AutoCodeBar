import Testing

@testable import AutoCodeBarCore

@Suite("按键脚本")
struct KeystrokeScriptTests {
  @Test("逐字符展开，带连字符的验证码也一样")
  func expandsCharacters() {
    let script = KeystrokeScript.make(text: "48-29", pressReturn: false)
    #expect(script == [
      .character("4"), .character("8"), .character("-"), .character("2"), .character("9")
    ])
  }

  @Test("需要回车时追加在末尾")
  func appendsReturn() {
    let script = KeystrokeScript.make(text: "482913", pressReturn: true)
    #expect(script.count == 7)
    #expect(script.last == .returnKey)
    #expect(script.dropLast() == KeystrokeScript.make(text: "482913", pressReturn: false)[...])
  }

  @Test("空验证码不产生任何按键，回车也不按")
  func emptyTextProducesNothing() {
    #expect(KeystrokeScript.make(text: "", pressReturn: false).isEmpty)
    #expect(KeystrokeScript.make(text: "", pressReturn: true).isEmpty)
  }
}
