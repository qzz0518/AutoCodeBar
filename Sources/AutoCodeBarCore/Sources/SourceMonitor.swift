import Foundation

/// 监听器向外发出的事件。
public enum SourceEvent: Sendable {
  case status(SourceStatus)
  case candidate(Candidate)
}

/// 数据源监听器协议。每次 `start()` 返回一条新流，流结束即监听结束。
public protocol SourceMonitor: AnyObject {
  var kind: SourceKind { get }
  func start() -> AsyncStream<SourceEvent>
  func stop()
}
