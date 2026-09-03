import Foundation
import os

/// 「信息」数据库监听器。
public final class MessagesMonitor: SourceMonitor {
  public let kind: SourceKind = .messages

  private static let query = """
    SELECT m.ROWID, m.text, m.attributedBody, h.id, m.date, m.service
    FROM message m
    LEFT JOIN handle h ON h.ROWID = m.handle_id
    WHERE m.ROWID > ?
      AND m.is_from_me = 0
      AND m.item_type = 0
      AND m.associated_message_type = 0
    ORDER BY m.ROWID ASC
    LIMIT 50;
    """

  private let databaseURL: URL
  private let queue = DispatchQueue(label: "dev.qiuzezheng.autocodebar.messages", qos: .utility)
  private let logger = Logger(subsystem: "dev.qiuzezheng.AutoCodeBar", category: "messages")

  private var continuation: AsyncStream<SourceEvent>.Continuation?
  private var watcher: FSEventsWatcher?
  private var pending: DispatchWorkItem?
  private var lastRowID: Int64 = 0
  private var consecutiveFailures = 0
  private var started = false

  public init(databaseURL: URL? = nil) {
    self.databaseURL = databaseURL ?? FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Messages/chat.db")
  }

  deinit {
    watcher?.stop()
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
      self.logger.info("stop messages monitor")
      self.started = false
      self.pending?.cancel()
      self.pending = nil
      self.watcher?.stop()
      self.watcher = nil
      self.continuation?.finish()
      self.continuation = nil
    }
  }

  // MARK: - 启动

  private func begin(_ continuation: AsyncStream<SourceEvent>.Continuation) {
    self.continuation = continuation
    started = true
    consecutiveFailures = 0
    logger.info("start messages monitor")
    emit(.starting)

    guard FileManager.default.fileExists(atPath: databaseURL.path) else {
      finish(with: .unavailable(L10n.text("未找到「信息」数据库", table: "Core")))
      return
    }

    do {
      lastRowID = try readMaxRowID()
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

    let directory = databaseURL.deletingLastPathComponent().path
    let watcher = FSEventsWatcher(paths: [directory], latency: 0.3, queue: queue) { [weak self] paths in
      self?.handle(paths: paths)
    }
    do {
      try watcher.start()
    } catch {
      finish(with: .failed(L10n.text("无法监听「信息」目录", table: "Core")))
      return
    }
    self.watcher = watcher
    emit(.running)
  }

  private func readMaxRowID() throws -> Int64 {
    let connection = try SQLiteConnection(path: databaseURL.path)
    defer { connection.close() }
    let statement = try connection.prepare("SELECT COALESCE(MAX(ROWID), 0) FROM message")
    guard try statement.step() else {
      return 0
    }
    return statement.int64(0)
  }

  // MARK: - 事件

  private func handle(paths: [String]) {
    let matched = paths.contains { (($0 as NSString).lastPathComponent).hasPrefix("chat.db") }
    guard matched, started else {
      return
    }
    pending?.cancel()
    let work = DispatchWorkItem { [weak self] in
      self?.drain()
    }
    pending = work
    queue.asyncAfter(deadline: .now() + 0.4, execute: work)
  }

  private func drain() {
    guard started else {
      return
    }
    do {
      let connection = try SQLiteConnection(path: databaseURL.path)
      defer { connection.close() }
      let statement = try connection.prepare(MessagesMonitor.query)
      statement.bind(lastRowID, at: 1)

      var maxRowID = lastRowID
      var produced: [Candidate] = []
      while try statement.step() {
        let rowID = statement.int64(0)
        maxRowID = max(maxRowID, rowID)
        guard let candidate = makeCandidate(rowID: rowID, statement: statement) else {
          continue
        }
        produced.append(candidate)
      }
      lastRowID = maxRowID
      consecutiveFailures = 0
      for candidate in produced {
        continuation?.yield(.candidate(candidate))
      }
    } catch {
      consecutiveFailures += 1
      logger.error("messages read failed: \(String(describing: error), privacy: .public)")
      if consecutiveFailures >= 5 {
        finish(with: .failed(L10n.text("读取「信息」数据库失败", table: "Core")))
      }
    }
  }

  private func makeCandidate(rowID: Int64, statement: SQLiteStatement) -> Candidate? {
    var body = statement.text(1)?.trimmingCharacters(in: .whitespacesAndNewlines)
    if body?.isEmpty != false {
      body = TypedStreamText.string(from: statement.data(2))?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard let text = body, !text.isEmpty else {
      return nil
    }

    let handle = statement.text(3)
    let receivedAt = MessagesMonitor.date(from: statement.int64(4))
    guard Date().timeIntervalSince(receivedAt) <= 600 else {
      return nil
    }

    return Candidate(
      kind: .messages,
      identity: "rowid:\(rowID)",
      senderIdentifier: handle,
      senderDisplay: SenderDisplay.forMessage(text: text, handle: handle),
      subject: nil,
      text: text,
      receivedAt: receivedAt
    )
  }

  /// `message.date` 为 Apple 参考日期起的纳秒（新系统）或秒（旧系统）。
  static func date(from raw: Int64) -> Date {
    let seconds = raw > 10_000_000_000 ? Double(raw) / 1_000_000_000 : Double(raw)
    return Date(timeIntervalSinceReferenceDate: seconds)
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
    continuation?.finish()
    continuation = nil
  }
}
