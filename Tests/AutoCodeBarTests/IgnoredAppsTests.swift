import AppKit
import Foundation
import Testing

@testable import AutoCodeBar
@testable import AutoCodeBarCore

@Suite("忽略应用列表")
@MainActor
struct IgnoredAppsTests {
  /// 每个用例一块独立的偏好域，`AppState` 的写回不会相互串味。
  private func makeState() -> AppState {
    let suite = "AutoCodeBarTests.ignoredApps.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite) ?? .standard
    defaults.removePersistentDomain(forName: suite)
    let state = AppState(updater: AppUpdater(), defaults: defaults)
    state.settings.ignoredNotificationApps = []
    return state
  }

  @Test("添加时统一转小写并去掉两端空白")
  func addNormalizesCase() {
    let state = makeState()
    state.addIgnoredApps(["  COM.Example.App  "])
    #expect(state.settings.ignoredNotificationApps == ["com.example.app"])
  }

  @Test("重复的 Bundle ID 只保留第一次出现的位置")
  func addDeduplicates() {
    let state = makeState()
    state.addIgnoredApps(["com.a", "com.b"])
    state.addIgnoredApps(["COM.A", "com.c", "com.c"])
    #expect(state.settings.ignoredNotificationApps == ["com.a", "com.b", "com.c"])
  }

  @Test("空字符串不占位")
  func addSkipsEmpty() {
    let state = makeState()
    state.addIgnoredApps(["", "   ", "com.a"])
    #expect(state.settings.ignoredNotificationApps == ["com.a"])
  }

  @Test("自身 Bundle ID 加不进去")
  func addExcludesSelf() {
    let state = makeState()
    state.addIgnoredApps([state.ownBundleIdentifier.uppercased(), "com.a"])
    #expect(state.settings.ignoredNotificationApps == ["com.a"])
  }

  @Test("移除不区分大小写")
  func removeIgnoresCase() {
    let state = makeState()
    state.addIgnoredApps(["com.a", "com.b"])
    state.removeIgnoredApp("COM.A")
    #expect(state.settings.ignoredNotificationApps == ["com.b"])
  }

  @Test("移除不存在的项不改动列表")
  func removeUnknownIsNoop() {
    let state = makeState()
    state.addIgnoredApps(["com.a"])
    state.removeIgnoredApp("com.zzz")
    #expect(state.settings.ignoredNotificationApps == ["com.a"])
  }

  @Test("恢复默认换回出厂列表")
  func restoreDefaults() {
    let state = makeState()
    state.addIgnoredApps(["com.a"])
    state.restoreDefaultIgnoredApps()
    #expect(state.settings.ignoredNotificationApps == AppSettings.defaultIgnoredNotificationApps)
  }
}

@Suite("添加应用列表的来源")
@MainActor
struct IgnoredAppSourcesTests {
  @Test("运行中的应用：只留 .regular、去掉自身、按名称排序、图标为 16pt")
  func runningApplications() {
    let own = "cc.zerah.autocodebar"
    let apps = RunningApp.current(excluding: own)

    // 至少有本进程之外的一个前台应用（访达一直在跑）。
    #expect(!apps.isEmpty)
    #expect(!apps.contains { $0.id == own })
    #expect(apps.allSatisfy { $0.id == $0.id.lowercased() })
    #expect(Set(apps.map(\.id)).count == apps.count)
    #expect(apps.allSatisfy { $0.icon.size == NSSize(width: 16, height: 16) })

    let names = apps.map(\.name)
    #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })

    let foreground = Set(
      NSWorkspace.shared.runningApplications
        .filter { $0.activationPolicy == .regular }
        .compactMap { $0.bundleIdentifier?.lowercased() }
    )
    #expect(Set(apps.map(\.id)) == foreground.subtracting([own]))
  }

  @Test("从访达选中的 .app 能读出 Bundle ID，选错东西则跳过")
  func bundleIdentifiersFromURLs() throws {
    let finder = try #require(
      NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder")
    )
    let notAnApp = URL(fileURLWithPath: "/usr/share/dict")
    let identifiers = IgnoredAppInfo.bundleIdentifiers(at: [finder, notAnApp])
    #expect(identifiers == ["com.apple.finder"])
  }

  @Test("解析已安装应用给出名称与图标，未安装只给占位图标")
  func lookupResolvesInstalledApps() {
    let finder = IgnoredAppInfo.lookup("com.apple.finder")
    #expect(finder.name?.isEmpty == false)
    #expect(finder.icon.size.width > 0)

    let missing = IgnoredAppInfo.lookup("cc.zerah.definitely.not.installed")
    #expect(missing.name == nil)
    #expect(missing.icon.size.width > 0)
  }
}
