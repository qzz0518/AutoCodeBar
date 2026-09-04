import CoreGraphics
import Darwin
import Foundation

/// 一次按键。验证码只会产生字符键，回车是可选的收尾。
public enum Keystroke: Equatable, Sendable {
  case character(Character)
  case returnKey
}

/// 把一串验证码翻译成按键序列。纯函数，便于测试。
public enum KeystrokeScript {
  /// 逐字符 + 可选回车。空串永远得到空脚本——没有验证码就不该按回车。
  public static func make(text: String, pressReturn: Bool) -> [Keystroke] {
    guard !text.isEmpty else {
      return []
    }
    var script = text.map { Keystroke.character($0) }
    if pressReturn {
      script.append(.returnKey)
    }
    return script
  }
}

/// 按键投递。
public protocol KeystrokeSender: AnyObject, Sendable {
  /// 在调用方之外的线程按序投递；调用后立即返回。
  func send(_ script: [Keystroke])
}

/// CGEvent 实现。
public final class CGEventKeystrokeSender: KeystrokeSender {
  /// 串行队列：按键必须严格有序，而且不能占着主线程睡觉。
  private let queue = DispatchQueue(
    label: "cc.zerah.AutoCodeBar.keystrokes",
    qos: .userInteractive
  )

  public init() {}

  public func send(_ script: [Keystroke]) {
    guard !script.isEmpty else {
      return
    }
    queue.async {
      guard let source = CGEventSource(stateID: .combinedSessionState) else {
        return
      }
      for stroke in script {
        switch stroke {
        case .character(let character):
          Self.post(character, source: source)
        case .returnKey:
          Self.postReturn(source: source)
        }
        // 分格验证码框按每一次 keydown 跳格，一口气塞整串会丢字。
        usleep(12_000)
      }
    }
  }

  /// 不查键盘布局：直接把 Unicode 挂在一个虚拟键号为 0 的事件上，
  /// 这样非 ASCII 布局下也不会敲出别的字符。
  private static func post(_ character: Character, source: CGEventSource) {
    let units = Array(String(character).utf16)
    guard !units.isEmpty else {
      return
    }
    for isDown in [true, false] {
      guard let event = CGEvent(
        keyboardEventSource: source,
        virtualKey: 0,
        keyDown: isDown
      ) else {
        continue
      }
      event.flags = []
      units.withUnsafeBufferPointer { buffer in
        event.keyboardSetUnicodeString(
          stringLength: buffer.count,
          unicodeString: buffer.baseAddress
        )
      }
      event.post(tap: .cghidEventTap)
    }
  }

  /// 虚拟键 36 = Return。
  private static func postReturn(source: CGEventSource) {
    for isDown in [true, false] {
      guard let event = CGEvent(
        keyboardEventSource: source,
        virtualKey: 36,
        keyDown: isDown
      ) else {
        continue
      }
      event.flags = []
      event.post(tap: .cghidEventTap)
    }
  }
}
