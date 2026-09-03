import AppKit
import UniformTypeIdentifiers

/// 忽略列表里一个 Bundle ID 的展示信息。
///
/// 解析一次要在磁盘上找到应用、打开它的 Info.plist、再抠出图标；列表每帧都会
/// 问一遍每一行，所以结果按 Bundle ID 记住。只在主线程用，缓存不需要加锁。
@MainActor
struct IgnoredAppInfo {
  let bundleIdentifier: String
  /// 本机没装这个应用时为 nil——界面据此改用等宽的 Bundle ID 顶替名称。
  let name: String?
  let icon: NSImage

  private static var cache: [String: IgnoredAppInfo] = [:]

  static func lookup(_ bundleIdentifier: String) -> IgnoredAppInfo {
    if let hit = cache[bundleIdentifier] {
      return hit
    }
    let resolved = resolve(bundleIdentifier)
    cache[bundleIdentifier] = resolved
    return resolved
  }

  /// 反过来：从访达里选中的 `.app` 读出 Bundle ID。读不出的（选到的不是应用包，
  /// 或者包里没有 Info.plist）直接跳过：少一个条目好过多一个空条目。
  static func bundleIdentifiers(at urls: [URL]) -> [String] {
    urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
  }

  private static func resolve(_ bundleIdentifier: String) -> IgnoredAppInfo {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
      return IgnoredAppInfo(
        bundleIdentifier: bundleIdentifier,
        name: nil,
        icon: NSWorkspace.shared.icon(for: .applicationBundle)
      )
    }
    let bundle = Bundle(url: url)
    // 显示名优先：本地化过的应用两者常常不一样，用户在访达里看到的是前者。
    let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
      ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
      ?? url.deletingPathExtension().lastPathComponent
    return IgnoredAppInfo(
      bundleIdentifier: bundleIdentifier,
      name: name,
      icon: NSWorkspace.shared.icon(forFile: url.path)
    )
  }
}
