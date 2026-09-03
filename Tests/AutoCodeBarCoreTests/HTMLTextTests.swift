import Foundation
import Testing

@testable import AutoCodeBarCore

@Suite("HTMLText")
struct HTMLTextTests {
  @Test("style / script / 注释被移除")
  func dropsNonContent() {
    let html = """
      <html><head><style>.a{color:red}</style><script>var a = 1 < 2;</script></head>
      <body><!-- hidden 999999 --><p>验证码 482913</p></body></html>
      """
    let text = HTMLText.plainText(from: html)
    #expect(!text.contains("color"))
    #expect(!text.contains("var a"))
    #expect(!text.contains("999999"))
    #expect(text.contains("验证码 482913"))
  }

  @Test("块级标签变换行，td 变制表符")
  func blockBreaks() {
    let text = HTMLText.plainText(from: "<div>A</div><p>B</p>C<br>D<table><tr><td>E</td><td>F</td></tr></table>")
    #expect(text.contains("A\nB"))
    #expect(text.contains("C\nD"))
    #expect(text.contains("E\tF"))
  }

  @Test("命名 / 十进制 / 十六进制实体")
  func entities() {
    let text = HTMLText.plainText(from: "<p>a&nbsp;b &amp; &lt;c&gt; &quot;d&quot; &#20320;&#x4F60;</p>")
    #expect(text.contains("a b & <c> \"d\" 你你"))
  }

  @Test("换行结构被保留")
  func keepsLines() {
    let text = HTMLText.plainText(from: "<p>验证码</p><p>482913</p><p>5 分钟内有效</p>")
    #expect(text == "验证码\n482913\n5 分钟内有效")
  }
}
