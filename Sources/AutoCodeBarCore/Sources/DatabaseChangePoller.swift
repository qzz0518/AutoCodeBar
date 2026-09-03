import Foundation

/// 定时比对 SQLite 数据库及其 WAL 文件的修改时间与大小，变化时回调。
///
/// 系统守护进程写入 chat.db 与通知数据库时，fseventsd 并不会为 WAL 文件产生事件，
/// 只靠 FSEvents 会漏掉新消息。这里每秒做两次 `stat`，开销可以忽略，
/// 有变化才真正打开数据库读取。
final class DatabaseChangePoller {
  private let paths: [String]
  private let timer: DispatchSourceTimer
  private let onChange: () -> Void
  private var lastSignature: String

  private enum State {
    case idle, running, stopped
  }
  private var state: State = .idle

  init(databaseURL: URL, queue: DispatchQueue, interval: TimeInterval = 1.0, onChange: @escaping () -> Void) {
    let database = databaseURL.path
    paths = [database, database + "-wal"]
    self.onChange = onChange
    lastSignature = DatabaseChangePoller.signature(of: paths)
    timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(200))
    timer.setEventHandler { [weak self] in
      self?.tick()
    }
  }

  deinit {
    stop()
  }

  func start() {
    guard state == .idle else {
      return
    }
    state = .running
    timer.resume()
  }

  /// 可重复调用；`deinit` 也会再调一次。
  func stop() {
    switch state {
    case .stopped:
      return
    case .idle:
      // 从未 resume 过的 DispatchSource 必须先 resume 再 cancel，否则释放时会崩溃。
      timer.setEventHandler {}
      timer.resume()
      timer.cancel()
    case .running:
      timer.cancel()
    }
    state = .stopped
  }

  private func tick() {
    let current = DatabaseChangePoller.signature(of: paths)
    guard current != lastSignature else {
      return
    }
    lastSignature = current
    onChange()
  }

  private static func signature(of paths: [String]) -> String {
    paths.map { path -> String in
      var info = stat()
      guard stat(path, &info) == 0 else {
        return "-"
      }
      return "\(info.st_mtimespec.tv_sec).\(info.st_mtimespec.tv_nsec):\(info.st_size)"
    }.joined(separator: "|")
  }
}
