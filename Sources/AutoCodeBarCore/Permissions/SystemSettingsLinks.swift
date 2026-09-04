import AppKit
import Foundation

/// 打开系统设置的对应面板。
public enum SystemSettingsLinks {
  public static func openFullDiskAccess() {
    open("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
  }

  public static func openNotifications() {
    if !open("x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
      _ = open("x-apple.systempreferences:com.apple.preference.notifications")
    }
  }

  public static func openAccessibility() {
    open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
  }

  @discardableResult
  private static func open(_ urlString: String) -> Bool {
    guard let url = URL(string: urlString) else {
      return false
    }
    return NSWorkspace.shared.open(url)
  }
}
