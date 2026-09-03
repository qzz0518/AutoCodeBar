import Foundation

/// 内存历史，最新在前，固定上限 20 条。
public struct History: Equatable {
  public static let limit = 20

  public private(set) var events: [CodeEvent] = []

  public init(events: [CodeEvent] = []) {
    self.events = Array(events.prefix(History.limit))
  }

  public mutating func insert(_ event: CodeEvent) {
    events.insert(event, at: 0)
    if events.count > History.limit {
      events.removeLast(events.count - History.limit)
    }
  }

  public mutating func remove(id: UUID) {
    events.removeAll { $0.id == id }
  }

  public mutating func clear() {
    events.removeAll()
  }

  public var isEmpty: Bool {
    events.isEmpty
  }
}
