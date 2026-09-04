import AppKit
import ApplicationServices

/// 当前聚焦的文本输入元素。
///
/// `AXUIElement` 是 CoreFoundation 对象，跨线程传递是安全的；探测跑在私有串行
/// 队列上、结果回主线程，所以这里显式声明 Sendable。
struct FocusedField: @unchecked Sendable {
  let element: AXUIElement
  let pid: pid_t
  /// AppKit 全局坐标（原点主屏左下）。
  let frame: NSRect
}

/// 读取前台应用的聚焦元素。
enum FocusProbe {
  /// 可以代填的角色。`AXSecureTextField`（密码框）明确不在其中。
  private static let acceptedRoles: Set<String> = [
    "AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"
  ]

  /// 已经设过 `AXManualAccessibility` 的进程；每个 pid 只设一次。
  private static let lock = NSLock()
  nonisolated(unsafe) private static var manualAccessibilityPIDs = Set<pid_t>()

  /// 同步；在 `QuickFillController` 的私有串行队列上调用，不要在主线程。
  ///
  /// `primaryScreenHeight` 由调用方从主线程读好传进来——`NSScreen.screens`
  /// 不该在后台线程碰。
  static func current(excludingPID own: pid_t, primaryScreenHeight: CGFloat) -> FocusedField? {
    guard let front = NSWorkspace.shared.frontmostApplication else {
      return nil
    }
    let pid = front.processIdentifier
    guard pid != own else {
      return nil
    }

    let app = AXUIElementCreateApplication(pid)
    // 无响应的应用不能把 250ms 的轮询拖住。
    _ = AXUIElementSetMessagingTimeout(app, 0.25)
    enableManualAccessibility(app, pid: pid)

    guard let element = copyElement(app, kAXFocusedUIElementAttribute) else {
      return nil
    }
    guard let role = copyString(element, kAXRoleAttribute), acceptedRoles.contains(role) else {
      return nil
    }
    guard let position = copyPoint(element, kAXPositionAttribute),
          let size = copySize(element, kAXSizeAttribute),
          size.width > 0, size.height > 0 else {
      return nil
    }

    // AX 给的是 Quartz 坐标（主屏左上原点），AppKit 从左下往上长。
    let frame = NSRect(
      x: position.x,
      y: primaryScreenHeight - position.y - size.height,
      width: size.width,
      height: size.height
    )
    return FocusedField(element: element, pid: pid, frame: frame)
  }

  /// 旧版 Chrome 与 Electron 应用靠这个属性才打开无障碍树。不支持的应用
  /// 返回 `attributeUnsupported`，忽略即可。
  private static func enableManualAccessibility(_ app: AXUIElement, pid: pid_t) {
    lock.lock()
    let isFirstTime = manualAccessibilityPIDs.insert(pid).inserted
    lock.unlock()
    guard isFirstTime else {
      return
    }
    _ = AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
  }

  // MARK: - 属性读取

  private static func copyValue(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
      return nil
    }
    return value
  }

  private static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
    guard let value = copyValue(element, attribute),
          CFGetTypeID(value) == AXUIElementGetTypeID() else {
      return nil
    }
    return (value as! AXUIElement)
  }

  private static func copyString(_ element: AXUIElement, _ attribute: String) -> String? {
    copyValue(element, attribute) as? String
  }

  private static func copyPoint(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
    guard let value = axValue(element, attribute) else {
      return nil
    }
    var point = CGPoint.zero
    guard AXValueGetValue(value, .cgPoint, &point) else {
      return nil
    }
    return point
  }

  private static func copySize(_ element: AXUIElement, _ attribute: String) -> CGSize? {
    guard let value = axValue(element, attribute) else {
      return nil
    }
    var size = CGSize.zero
    guard AXValueGetValue(value, .cgSize, &size) else {
      return nil
    }
    return size
  }

  private static func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
    guard let value = copyValue(element, attribute), CFGetTypeID(value) == AXValueGetTypeID() else {
      return nil
    }
    return (value as! AXValue)
  }
}
