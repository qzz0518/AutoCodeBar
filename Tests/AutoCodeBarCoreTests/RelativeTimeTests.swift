import Foundation
import Testing

@testable import AutoCodeBarCore

@Suite("RelativeTime")
struct RelativeTimeTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
    return calendar
  }

  private var now: Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 9
    components.day = 4
    components.hour = 15
    components.minute = 30
    return calendar.date(from: components) ?? Date()
  }

  @Test("60 秒内显示「刚刚」")
  func justNow() {
    #expect(RelativeTime.string(for: now.addingTimeInterval(-30), now: now, calendar: calendar) == "刚刚")
  }

  @Test("一小时内显示分钟")
  func minutes() {
    #expect(RelativeTime.string(for: now.addingTimeInterval(-180), now: now, calendar: calendar) == "3 分钟前")
  }

  @Test("同一天显示时刻")
  func sameDay() {
    #expect(RelativeTime.string(for: now.addingTimeInterval(-7200), now: now, calendar: calendar) == "13:30")
  }

  @Test("昨天带前缀")
  func yesterday() {
    let date = calendar.date(byAdding: .day, value: -1, to: now) ?? now
    #expect(RelativeTime.string(for: date, now: now, calendar: calendar) == "昨天 15:30")
  }

  @Test("更早显示月日")
  func earlier() {
    let date = calendar.date(byAdding: .day, value: -5, to: now) ?? now
    #expect(RelativeTime.string(for: date, now: now, calendar: calendar) == "8月30日 15:30")
  }
}
