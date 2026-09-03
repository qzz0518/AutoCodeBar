import AppKit
import Foundation
import os

/// 系统通知数据库监听器（实验特性）。
public final class NotificationCenterMonitor: SourceMonitor {
  public let kind: SourceKind = .notificationCenter

  private static let query = """
    SELECT r.rec_id, a.identifier, r.data, r.delivered_date
    FROM record r LEFT JOIN app a ON a.app_id = r.app_id
    WHERE r.rec_id > ? ORDER BY r.rec_id ASC LIMIT 50;
    """

  private let queue = DispatchQueue(label: "cc.zerah.autocodebar.notificationCenter", qos: .utility)
  private let logger = Logger(subsystem: "cc.zerah.AutoCodeBar", category: "notificationCenter")
  private let overrideURL: URL?

  private var databaseURL: URL?
  private var continuation: AsyncStream<SourceEvent>.Continuation?
  private var watcher: FSEventsWatcher?
  private var poller: DatabaseChangePoller?
  private var pending: DispatchWorkItem?
  private var lastRecordID: Int64 = 0
  private var consecutiveFailures = 0
  private var started = false
  private var appNameCache: [String: String] = [:]

  public init(databaseURL: URL? = nil) {
    self.overrideURL = databaseURL
  }

  deinit {
    watcher?.stop()
    poller?.stop()
  }

  /// 定位系统通知数据库。
  public static func locateDatabase() -> URL? {
    let group = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db")
    if FileManager.default.fileExists(atPath: group.path) {
      return group
    }
    if let darwin = DarwinPaths.darwinUserDirectory() {
      let legacy = URL(fileURLWithPath: darwin)
        .appendingPathComponent("com.apple.notificationcenter/db2/db")
      if FileManager.default.fileExists(atPath: legacy.path) {
        return legacy
      }
    }
    return nil
  }

  public func start() -> AsyncStream<SourceEvent> {
    var captured: AsyncStream<SourceEvent>.Continuation?
    let stream = AsyncStream<SourceEvent> { continuation in
      captured = continuation
    }
    guard let continuation = captured else {
      return stream
    }
    queue.async { [weak self] in
      self?.begin(continuation)
    }
    return stream
  }

  public func stop() {
    queue.async { [weak self] in
      guard let self else {
        return
      }
      guard self.started else {
        self.continuation?.finish()
        self.continuation = nil
        return
      }
      self.logger.info("stop notificationCenter monitor")
      self.started = false
      self.pending?.cancel()
      self.pending = nil
      self.watcher?.stop()
      self.watcher = nil
      self.poller?.stop()
      self.poller = nil
      self.continuation?.finish()
      self.continuation = nil
    }
  }

  // MARK: - 启动

  private func begin(_ continuation: AsyncStream<SourceEvent>.Continuation) {
    self.continuation = continuation
    started = true
    consecutiveFailures = 0
    logger.info("start notificationCenter monitor")
    emit(.starting)

    guard let url = overrideURL ?? NotificationCenterMonitor.locateDatabase() else {
      finish(with: .unavailable(L10n.text("未找到系统通知数据库", table: "Core")))
      return
    }
    databaseURL = url

    do {
      lastRecordID = try readMaxRecordID(url: url)
    } catch let error as SQLiteError {
      if error.looksLikePermissionDenied {
        finish(with: .needsFullDiskAccess)
      } else {
        finish(with: .failed(error.description))
      }
      return
    } catch {
      finish(with: .failed(error.localizedDescription))
      return
    }

    let directory = url.deletingLastPathComponent().path
    let watcher = FSEventsWatcher(paths: [directory], latency: 0.5, queue: queue) { [weak self] paths in
      self?.handle(paths: paths)
    }
    do {
      try watcher.start()
    } catch {
      finish(with: .failed(L10n.text("无法监听系统通知数据库目录", table: "Core")))
      return
    }
    self.watcher = watcher

    // 守护进程写通知数据库时 fseventsd 不一定发事件，轮询兜底。
    let poller = DatabaseChangePoller(databaseURL: url, queue: queue) { [weak self] in
      self?.scheduleDrain()
    }
    poller.start()
    self.poller = poller
    emit(.running)
  }

  private func readMaxRecordID(url: URL) throws -> Int64 {
    let connection = try SQLiteConnection(path: url.path)
    defer { connection.close() }
    let statement = try connection.prepare("SELECT COALESCE(MAX(rec_id), 0) FROM record")
    guard try statement.step() else {
      return 0
    }
    return statement.int64(0)
  }

  // MARK: - 事件

  static func isInteresting(path: String) -> Bool {
    let name = (path as NSString).lastPathComponent
    return name.hasPrefix("db") && !name.contains("corrupt")
  }

  private func handle(paths: [String]) {
    guard started, paths.contains(where: { NotificationCenterMonitor.isInteresting(path: $0) }) else {
      return
    }
    scheduleDrain()
  }

  private func scheduleDrain() {
    guard started else {
      return
    }
    pending?.cancel()
    let work = DispatchWorkItem { [weak self] in
      self?.drain()
    }
    pending = work
    queue.asyncAfter(deadline: .now() + 0.5, execute: work)
  }

  private func drain() {
    guard started, let url = databaseURL else {
      return
    }
    do {
      let connection = try SQLiteConnection(path: url.path)
      defer { connection.close() }
      let statement = try connection.prepare(NotificationCenterMonitor.query)
      statement.bind(lastRecordID, at: 1)

      var maxRecordID = lastRecordID
      var produced: [Candidate] = []
      while try statement.step() {
        let recordID = statement.int64(0)
        maxRecordID = max(maxRecordID, recordID)
        guard let candidate = makeCandidate(recordID: recordID, statement: statement) else {
          continue
        }
        produced.append(candidate)
      }
      lastRecordID = maxRecordID
      consecutiveFailures = 0
      for candidate in produced {
        continuation?.yield(.candidate(candidate))
      }
    } catch {
      consecutiveFailures += 1
      logger.error("notificationCenter read failed: \(String(describing: error), privacy: .public)")
      if consecutiveFailures >= 5 {
        finish(with: .failed(L10n.text("读取系统通知数据库失败", table: "Core")))
      }
    }
  }

  private func makeCandidate(recordID: Int64, statement: SQLiteStatement) -> Candidate? {
    guard let record = NotificationRecord.parse(statement.data(2)) else {
      return nil
    }
    let text = record.text
    guard !text.isEmpty else {
      return nil
    }

    let identifier = (statement.text(1) ?? record.bundleIdentifier)?.lowercased()
    let delivered = statement.double(3)
    let receivedAt: Date
    if delivered > 0 {
      receivedAt = Date(timeIntervalSinceReferenceDate: delivered)
    } else if let date = record.date {
      receivedAt = date
    } else {
      receivedAt = Date()
    }
    guard Date().timeIntervalSince(receivedAt) <= 600 else {
      return nil
    }

    return Candidate(
      kind: .notificationCenter,
      identity: "rec:\(recordID)",
      senderIdentifier: identifier,
      senderDisplay: record.title ?? applicationName(for: identifier) ?? identifier,
      subject: nil,
      text: text,
      receivedAt: receivedAt
    )
  }

  private func applicationName(for bundleIdentifier: String?) -> String? {
    guard let bundleIdentifier, !bundleIdentifier.isEmpty else {
      return nil
    }
    if let cached = appNameCache[bundleIdentifier] {
      return cached
    }
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
          let bundle = Bundle(url: url) else {
      return nil
    }
    let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
      ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
    if let name {
      appNameCache[bundleIdentifier] = name
    }
    return name
  }

  // MARK: - 工具

  private func emit(_ status: SourceStatus) {
    logger.info("status \(String(describing: status), privacy: .public)")
    continuation?.yield(.status(status))
  }

  private func finish(with status: SourceStatus) {
    emit(status)
    started = false
    pending?.cancel()
    pending = nil
    watcher?.stop()
    watcher = nil
    poller?.stop()
    poller = nil
    continuation?.finish()
    continuation = nil
  }
}
