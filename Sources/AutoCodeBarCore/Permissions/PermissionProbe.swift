import Darwin
import Foundation
import UserNotifications

/// 权限探测。
public enum PermissionProbe {
  public enum FDAState: Equatable, Sendable {
    /// 至少一处受保护数据可读。
    case granted
    /// 存在受保护数据但被拒绝。
    case denied
    /// 「信息」数据库与「邮件」目录都不存在，无法判断。
    case noData
  }

  public static var messagesDatabaseURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Messages/chat.db")
  }

  public static var mailDirectoryURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Mail")
  }

  /// 单个路径的可读性。
  enum Readability: Equatable {
    case readable
    case denied
    case missing
  }

  /// `open(O_RDONLY)` + errno。比开 SQLite 便宜得多，也不会在数据库上留痕。
  static func probeFile(_ path: String) -> Readability {
    let fd = open(path, O_RDONLY)
    if fd >= 0 {
      close(fd)
      return .readable
    }
    switch errno {
    case EPERM, EACCES:
      return .denied
    case ENOENT:
      // TCC 同时会挡住列出父目录，所以「文件不存在 + 父目录不可读」仍然是被拒绝。
      let parent = (path as NSString).deletingLastPathComponent
      if access(parent, R_OK) != 0, errno == EPERM || errno == EACCES {
        return .denied
      }
      return .missing
    default:
      return .missing
    }
  }

  /// 目录用 `opendir` / `access(R_OK)`。
  static func probeDirectory(_ path: String) -> Readability {
    if let handle = opendir(path) {
      closedir(handle)
      return .readable
    }
    switch errno {
    case EPERM, EACCES:
      return .denied
    case ENOENT:
      return .missing
    default:
      return .missing
    }
  }

  /// 同步、无副作用；可以在任意线程调用。
  public nonisolated static func fullDiskAccess() -> FDAState {
    let results = [
      probeFile(messagesDatabaseURL.path),
      probeDirectory(mailDirectoryURL.path)
    ]
    if results.contains(.readable) {
      return .granted
    }
    if results.contains(.denied) {
      return .denied
    }
    return .noData
  }

  public static func notificationAuthorization() async -> UNAuthorizationStatus {
    await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
  }
}
