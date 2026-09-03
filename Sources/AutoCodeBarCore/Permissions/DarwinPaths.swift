import Darwin
import Foundation

/// `confstr(_CS_DARWIN_USER_DIR)` 的 Swift 包装（不起子进程）。
public enum DarwinPaths {
  public static func darwinUserDirectory() -> String? {
    let size = confstr(_CS_DARWIN_USER_DIR, nil, 0)
    guard size > 0 else {
      return nil
    }
    var buffer = [CChar](repeating: 0, count: size)
    let written = confstr(_CS_DARWIN_USER_DIR, &buffer, size)
    guard written > 0 else {
      return nil
    }
    let path = String(cString: buffer)
    return path.isEmpty ? nil : path
  }
}
