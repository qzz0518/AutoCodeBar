import Foundation

/// 面板里的相对时间展示。
public enum RelativeTime {
  public static func string(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
    let interval = now.timeIntervalSince(date)

    if interval < 60 {
      return L10n.text("刚刚", table: "Core")
    }
    if interval < 3600 {
      return L10n.format("%d 分钟前", Int(interval / 60), table: "Core")
    }

    let formatter = DateFormatter()
    formatter.calendar = calendar
    // 语言决定的不只是「昨天」这两个字，还有月份日期的排法，
    // 所以格式串本身也是一条待翻译的条目。
    formatter.locale = L10n.locale()
    formatter.timeZone = calendar.timeZone

    if calendar.isDate(date, inSameDayAs: now) {
      formatter.dateFormat = L10n.text("HH:mm", table: "Core")
      return formatter.string(from: date)
    }

    if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
       calendar.isDate(date, inSameDayAs: yesterday) {
      formatter.dateFormat = L10n.text("昨天 HH:mm", table: "Core")
      return formatter.string(from: date)
    }

    formatter.dateFormat = L10n.text("M月d日 HH:mm", table: "Core")
    return formatter.string(from: date)
  }
}
