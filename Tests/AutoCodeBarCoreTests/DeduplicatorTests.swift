import Foundation
import Testing

@testable import AutoCodeBarCore

@Suite("Deduplicator")
struct DeduplicatorTests {
  @Test("299 秒内拒绝、301 秒后接受")
  func windowBoundary() {
    var now = Date(timeIntervalSince1970: 1_000_000)
    let dedup = Deduplicator(window: 300, now: { now })

    #expect(dedup.accept("482913"))
    now = now.addingTimeInterval(299)
    #expect(!dedup.accept("482913"))
    now = now.addingTimeInterval(2)
    #expect(dedup.accept("482913"))
  }

  @Test("键按大写比较")
  func caseInsensitive() {
    let dedup = Deduplicator(window: 300, now: { Date(timeIntervalSince1970: 0) })
    #expect(dedup.accept("rkj-yp6"))
    #expect(!dedup.accept("RKJ-YP6"))
  }
}
