import AppKit
import Foundation

/// 剪贴板抽象，便于测试注入。
public protocol Clipboard: AnyObject {
  func copy(_ text: String) -> Bool
}

/// 真实剪贴板；写入时附带 `org.nspasteboard.ConcealedType` 标记。
public final class PasteboardClipboard: Clipboard {
  public init() {}

  public func copy(_ text: String) -> Bool {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    let ok = pasteboard.setString(text, forType: .string)
    pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
    return ok
  }
}

/// 测试用空实现。
public final class NoopClipboard: Clipboard {
  public private(set) var copied: [String] = []
  public var succeeds = true

  public init(succeeds: Bool = true) {
    self.succeeds = succeeds
  }

  public func copy(_ text: String) -> Bool {
    copied.append(text)
    return succeeds
  }
}
