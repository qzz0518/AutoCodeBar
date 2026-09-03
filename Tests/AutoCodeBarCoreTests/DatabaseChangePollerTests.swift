import Foundation
import Testing

@testable import AutoCodeBarCore

@Suite("DatabaseChangePoller")
struct DatabaseChangePollerTests {
  private func makeDatabaseURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("poller-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("chat.db")
    try Data("db".utf8).write(to: url)
    try Data("wal".utf8).write(to: URL(fileURLWithPath: url.path + "-wal"))
    return url
  }

  @Test("WAL 大小变化触发回调，未变化不触发")
  func firesOnlyWhenWalChanges() async throws {
    let url = try makeDatabaseURL()
    let queue = DispatchQueue(label: "poller-test")
    let fired = Counter()
    let poller = DatabaseChangePoller(databaseURL: url, queue: queue, interval: 0.05) {
      fired.increment()
    }
    poller.start()
    defer { poller.stop() }

    try await Task.sleep(for: .milliseconds(200))
    #expect(fired.value == 0)

    try Data("wal-with-a-new-frame".utf8).write(to: URL(fileURLWithPath: url.path + "-wal"))
    try await Task.sleep(for: .milliseconds(300))
    #expect(fired.value == 1)

    try await Task.sleep(for: .milliseconds(200))
    #expect(fired.value == 1)
  }

  @Test("从未启动就停止不会崩溃")
  func stopWithoutStart() throws {
    let url = try makeDatabaseURL()
    let poller = DatabaseChangePoller(databaseURL: url, queue: DispatchQueue(label: "idle")) {}
    poller.stop()
  }
}

private final class Counter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0
  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return count
  }
  func increment() {
    lock.lock()
    count += 1
    lock.unlock()
  }
}
