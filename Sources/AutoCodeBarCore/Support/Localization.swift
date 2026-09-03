import Foundation

/// 界面文案的查表入口。
///
/// key 就是简体中文原文，`.strings` 缺失时回落到 key 本身——直跑 SwiftPM 产物
/// 或跑测试时没有 `.lproj` 目录，界面与断言仍然是中文。
public enum L10n {
    /// `Bundle.localizedString` 每次调用都要加锁并走一遍表，而视图 body 一帧里
    /// 会问几十次。应用没有内建语言切换，`Bundle.main` 的表在进程存活期间不会变，
    /// 所以主包的结果直接记住；注入的测试包不缓存，测试要看到实时查表。
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: [Key: String] = [:]
    nonisolated(unsafe) private static var mainLocale: Locale?

    private struct Key: Hashable {
        let table: String
        let key: String
    }

    /// 应用可以在「系统设置 › 通用 › 语言与地区 › 应用程序」里单独设语言，
    /// 因此包的偏好语言优先于 `Locale.current`。
    public static func locale(for bundle: Bundle = .main) -> Locale {
        guard bundle === Bundle.main else { return resolveLocale(bundle) }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let mainLocale { return mainLocale }
        let resolved = resolveLocale(bundle)
        mainLocale = resolved
        return resolved
    }

    private static func resolveLocale(_ bundle: Bundle) -> Locale {
        guard let identifier = bundle.preferredLocalizations.first, !identifier.isEmpty else {
            return .current
        }
        return Locale(identifier: identifier)
    }

    public static func text(
        _ key: String,
        table: String = "Localizable",
        bundle: Bundle = .main
    ) -> String {
        guard bundle === Bundle.main else {
            return bundle.localizedString(forKey: key, value: key, table: table)
        }
        let cacheKey = Key(table: table, key: key)
        cacheLock.lock()
        if let hit = cache[cacheKey] {
            cacheLock.unlock()
            return hit
        }
        cacheLock.unlock()

        // 在锁外解析：包自己也要加锁，两把锁叠在一起会让界面线程的查表
        // 排在后台查表后面。
        let resolved = bundle.localizedString(forKey: key, value: key, table: table)
        cacheLock.lock()
        cache[cacheKey] = resolved
        cacheLock.unlock()
        return resolved
    }

    public static func format(
        _ key: String,
        _ arguments: CVarArg...,
        table: String = "Localizable",
        bundle: Bundle = .main
    ) -> String {
        String(
            format: text(key, table: table, bundle: bundle),
            locale: locale(for: bundle),
            arguments: arguments
        )
    }
}
