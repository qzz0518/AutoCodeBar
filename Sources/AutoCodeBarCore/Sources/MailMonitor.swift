import Foundation
import os

/// 「邮件」本地 emlx 监听器。
public final class MailMonitor: SourceMonitor {
  public let kind: SourceKind = .mail

  private static let staleInterval: TimeInterval = 900
  private static let rememberInterval: TimeInterval = 600

  private let rootURL: URL
  private let queue = DispatchQueue(label: "dev.qiuzezheng.autocodebar.mail", qos: .utility)
  private let logger = Logger(subsystem: "dev.qiuzezheng.AutoCodeBar", category: "mail")

  private var continuation: AsyncStream<SourceEvent>.Continuation?
  private var watcher: FSEventsWatcher?
  private var seen: [String: Date] = [:]
  private var started = false

  public init(rootURL: URL? = nil) {
    self.rootURL = rootURL ?? FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Mail")
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
      self.logger.info("stop mail monitor")
      self.started = false
      self.watcher?.stop()
      self.watcher = nil
      self.seen.removeAll()
      self.continuation?.finish()
      self.continuation = nil
    }
  }

  // MARK: - 启动

  private func begin(_ continuation: AsyncStream<SourceEvent>.Continuation) {
    self.continuation = continuation
    started = true
    logger.info("start mail monitor")
    emit(.starting)

    guard FileManager.default.fileExists(atPath: rootURL.path) else {
      finish(with: .unavailable(L10n.text("未找到「邮件」数据目录", table: "Core")))
      return
    }

    do {
      _ = try FileManager.default.contentsOfDirectory(atPath: rootURL.path)
    } catch let error as NSError {
      if error.code == NSFileReadNoPermissionError || error.code == EPERM || error.code == EACCES {
        finish(with: .needsFullDiskAccess)
      } else {
        finish(with: .failed(L10n.text("无法读取「邮件」数据目录", table: "Core")))
      }
      return
    }

    let watcher = FSEventsWatcher(paths: [rootURL.path], latency: 0.5, queue: queue) { [weak self] paths in
      self?.handle(paths: paths)
    }
    do {
      try watcher.start()
    } catch {
      finish(with: .failed(L10n.text("无法监听「邮件」目录", table: "Core")))
      return
    }
    self.watcher = watcher
    emit(.running)
  }

  // MARK: - 事件

  static func isInteresting(path: String) -> Bool {
    guard path.hasSuffix(".emlx"), !path.hasSuffix(".partial.emlx") else {
      return false
    }
    return path.contains("/Messages/")
  }

  private func handle(paths: [String]) {
    guard started else {
      return
    }
    let now = Date()
    prune(now: now)

    for path in paths where MailMonitor.isInteresting(path: path) {
      if let last = seen[path], now.timeIntervalSince(last) < MailMonitor.rememberInterval {
        continue
      }
      seen[path] = now
      queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.read(path: path)
      }
    }
  }

  private func prune(now: Date) {
    seen = seen.filter { now.timeIntervalSince($0.value) < MailMonitor.rememberInterval }
  }

  private func read(path: String) {
    guard started, FileManager.default.fileExists(atPath: path) else {
      return
    }
    guard let data = FileManager.default.contents(atPath: path) else {
      return
    }
    guard let file = EmlxFile.parse(data) else {
      return
    }

    let message = MIMEMessage.parse(file.message)
    let receivedAt = file.dateReceived ?? message.date ?? modificationDate(path: path) ?? Date()
    guard Date().timeIntervalSince(receivedAt) <= MailMonitor.staleInterval else {
      return
    }

    let body = message.bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
    let subject = message.subject?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !body.isEmpty || !(subject ?? "").isEmpty else {
      return
    }

    let candidate = Candidate(
      kind: .mail,
      identity: path,
      senderIdentifier: message.fromAddress?.lowercased(),
      senderDisplay: SenderDisplay.fallback(message.fromDisplayName, message.fromAddress),
      subject: subject,
      text: body,
      receivedAt: receivedAt
    )
    continuation?.yield(.candidate(candidate))
  }

  private func modificationDate(path: String) -> Date? {
    let attributes = try? FileManager.default.attributesOfItem(atPath: path)
    return attributes?[.modificationDate] as? Date
  }

  // MARK: - 工具

  private func emit(_ status: SourceStatus) {
    logger.info("status \(String(describing: status), privacy: .public)")
    continuation?.yield(.status(status))
  }

  private func finish(with status: SourceStatus) {
    emit(status)
    started = false
    watcher?.stop()
    watcher = nil
    continuation?.finish()
    continuation = nil
  }
}
