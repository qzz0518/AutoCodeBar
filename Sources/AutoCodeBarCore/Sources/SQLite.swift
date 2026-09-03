import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum SQLiteError: Error, CustomStringConvertible {
  case cannotOpen(code: Int32, errno: Int32, message: String)
  case prepareFailed(String)
  case stepFailed(code: Int32, message: String)

  public var description: String {
    switch self {
    case .cannotOpen(_, _, let message): return message
    case .prepareFailed(let message): return message
    case .stepFailed(_, let message): return message
    }
  }

  /// 是否是权限问题（需要完整磁盘访问）。
  public var looksLikePermissionDenied: Bool {
    switch self {
    case .cannotOpen(let code, let systemErrno, _):
      if systemErrno == EPERM || systemErrno == EACCES {
        return true
      }
      return code == SQLITE_CANTOPEN || code == SQLITE_AUTH || code == SQLITE_PERM
    case .prepareFailed, .stepFailed:
      return false
    }
  }
}

/// 只读 SQLite 连接的薄封装。每次读取新开一次，用完即关（chat.db 是 WAL，长连接会看到陈旧快照）。
public final class SQLiteConnection {
  private var handle: OpaquePointer?

  public init(path: String) throws {
    let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
    let code = sqlite3_open_v2(path, &handle, flags, nil)
    if code != SQLITE_OK {
      let message = handle.flatMap { sqlite3_errmsg($0).map { String(cString: $0) } } ?? L10n.text("无法打开数据库", table: "Core")
      let systemErrno = handle.map { sqlite3_system_errno($0) } ?? 0
      sqlite3_close_v2(handle)
      handle = nil
      throw SQLiteError.cannotOpen(code: code, errno: systemErrno, message: message)
    }
    execute("PRAGMA query_only = ON")
    execute("PRAGMA busy_timeout = 1500")
  }

  deinit {
    sqlite3_close_v2(handle)
  }

  /// `sqlite3_close_v2` 会在最后一条语句 finalize 后才真正释放，因此提前调用是安全的。
  public func close() {
    sqlite3_close_v2(handle)
    handle = nil
  }

  @discardableResult
  public func execute(_ sql: String) -> Bool {
    sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK
  }

  public func prepare(_ sql: String) throws -> SQLiteStatement {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
      let message = handle.flatMap { sqlite3_errmsg($0).map { String(cString: $0) } } ?? L10n.text("SQL 编译失败", table: "Core")
      throw SQLiteError.prepareFailed(message)
    }
    return SQLiteStatement(statement: statement, database: handle)
  }
}

public final class SQLiteStatement {
  private let statement: OpaquePointer
  private let database: OpaquePointer?

  init(statement: OpaquePointer, database: OpaquePointer?) {
    self.statement = statement
    self.database = database
  }

  deinit {
    sqlite3_finalize(statement)
  }

  public func bind(_ value: Int64, at index: Int32) {
    sqlite3_bind_int64(statement, index, value)
  }

  public func bind(_ value: String, at index: Int32) {
    sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
  }

  /// 前进一行；有行返回 true。
  public func step() throws -> Bool {
    let code = sqlite3_step(statement)
    switch code {
    case SQLITE_ROW:
      return true
    case SQLITE_DONE:
      return false
    default:
      let message = database.flatMap { sqlite3_errmsg($0).map { String(cString: $0) } } ?? L10n.text("读取失败", table: "Core")
      throw SQLiteError.stepFailed(code: code, message: message)
    }
  }

  public func int64(_ index: Int32) -> Int64 {
    sqlite3_column_int64(statement, index)
  }

  public func double(_ index: Int32) -> Double {
    sqlite3_column_double(statement, index)
  }

  public func text(_ index: Int32) -> String? {
    guard let value = sqlite3_column_text(statement, index) else {
      return nil
    }
    return String(cString: value)
  }

  public func data(_ index: Int32) -> Data? {
    guard let bytes = sqlite3_column_blob(statement, index) else {
      return nil
    }
    let count = Int(sqlite3_column_bytes(statement, index))
    guard count > 0 else {
      return nil
    }
    return Data(bytes: bytes, count: count)
  }
}
