import CoreServices
import Foundation

/// FSEvents 目录监视。回调在构造时给定的队列上执行。
public final class FSEventsWatcher {
  public typealias Handler = ([String]) -> Void

  public enum WatcherError: Error, CustomStringConvertible {
    case createFailed
    case startFailed

    public var description: String {
      switch self {
      case .createFailed: return L10n.text("无法创建 FSEvents 监听", table: "Core")
      case .startFailed: return L10n.text("FSEvents 启动失败", table: "Core")
      }
    }
  }

  private let paths: [String]
  private let latency: CFTimeInterval
  private let queue: DispatchQueue
  private let handler: Handler
  private var stream: FSEventStreamRef?

  public init(paths: [String], latency: CFTimeInterval, queue: DispatchQueue, handler: @escaping Handler) {
    self.paths = paths
    self.latency = latency
    self.queue = queue
    self.handler = handler
  }

  deinit {
    stop()
  }

  public func start() throws {
    guard stream == nil else {
      return
    }

    var context = FSEventStreamContext(
      version: 0,
      info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
      retain: nil,
      release: nil,
      copyDescription: nil
    )

    let flags = FSEventStreamCreateFlags(
      kFSEventStreamCreateFlagUseCFTypes
        | kFSEventStreamCreateFlagFileEvents
        | kFSEventStreamCreateFlagNoDefer
    )

    guard let created = FSEventStreamCreate(
      kCFAllocatorDefault,
      FSEventsWatcher.callback,
      &context,
      paths as CFArray,
      FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
      latency,
      flags
    ) else {
      throw WatcherError.createFailed
    }

    stream = created
    FSEventStreamSetDispatchQueue(created, queue)
    if !FSEventStreamStart(created) {
      stop()
      throw WatcherError.startFailed
    }
  }

  public func stop() {
    guard let stream else {
      return
    }
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)
    self.stream = nil
  }

  private static let callback: FSEventStreamCallback = { _, info, count, eventPaths, _, _ in
    guard let info, count > 0 else {
      return
    }
    let watcher = Unmanaged<FSEventsWatcher>.fromOpaque(info).takeUnretainedValue()
    let array = unsafeBitCast(eventPaths, to: NSArray.self)
    let paths = array.compactMap { $0 as? String }
    if !paths.isEmpty {
      watcher.handler(paths)
    }
  }
}
