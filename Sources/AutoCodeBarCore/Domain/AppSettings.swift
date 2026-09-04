import Foundation

/// 应用设置（schema v2）。存储在 `UserDefaults.standard` 的 `AutoCodeBar.settings.v2` 键下。
public struct AppSettings: Codable, Equatable, Sendable {
  public static let storageKey = "AutoCodeBar.settings.v2"
  public static let legacyStorageKey = "AutoCodeBar.settings.v1"

  public var schemaVersion: Int
  public var sources: [SourceKind: Bool]
  public var showCopyNotification: Bool
  public var showCodeInMenuBar: Bool
  public var ignoredNotificationApps: [String]
  public var keywords: [String]
  public var codePattern: String
  public var onboardingCompleted: Bool
  /// 「在输入框旁显示填入按钮」。默认关闭，开了才需要辅助功能权限。
  public var quickFillEnabled: Bool
  /// 「填入后自动按回车」。
  public var quickFillPressesReturn: Bool

  public init(
    schemaVersion: Int = 2,
    sources: [SourceKind: Bool] = AppSettings.defaultSources,
    showCopyNotification: Bool = true,
    showCodeInMenuBar: Bool = true,
    ignoredNotificationApps: [String] = AppSettings.defaultIgnoredNotificationApps,
    keywords: [String] = AppSettings.defaultKeywords,
    codePattern: String = AppSettings.defaultCodePattern,
    onboardingCompleted: Bool = false,
    quickFillEnabled: Bool = false,
    quickFillPressesReturn: Bool = false
  ) {
    self.schemaVersion = schemaVersion
    self.sources = sources
    self.showCopyNotification = showCopyNotification
    self.showCodeInMenuBar = showCodeInMenuBar
    self.ignoredNotificationApps = ignoredNotificationApps
    self.keywords = keywords
    self.codePattern = codePattern
    self.onboardingCompleted = onboardingCompleted
    self.quickFillEnabled = quickFillEnabled
    self.quickFillPressesReturn = quickFillPressesReturn
  }

  public static let defaultSources: [SourceKind: Bool] = [
    .messages: true,
    .mail: true,
    .notificationCenter: false
  ]

  public static let defaultIgnoredNotificationApps: [String] = [
    "ru.keepcoder.telegram",
    "org.telegram.desktop",
    "com.tdesktop.telegram",
    "com.tdesktop.telegrammac",
    "ph.telegra.telegraph",
    "org.telegram.messenger"
  ]

  public static let defaultKeywords: [String] = [
    "验证码", "校验码", "动态密码", "动态码", "确认码", "安全码", "验证", "代码",
    "驗證碼", "驗證",
    "verif", "code", "OTP", "one-time", "2FA", "authenticat",
    "인증", "認証", "確認コード"
  ]

  public static let defaultCodePattern = "[A-Za-z0-9]{1,8}(?:-[A-Za-z0-9]{1,8})?"

  /// 1.x 的默认关键词。迁移时若用户没改过，就换成 2.0 调过的那套。
  public static let legacyDefaultKeywords: [String] = [
    "验证码", "动态密码", "验证", "校验码", "安全代码", "代码",
    "verification code", "captcha code", "security code", "one-time code",
    "verification", "captcha", "code", "OTP", "인증"
  ]

  /// 1.x 的默认正则。
  public static let legacyDefaultCodePattern = "(?=[A-Za-z0-9-]*[0-9])[A-Za-z0-9-]{4,8}"

  public func isEnabled(_ kind: SourceKind) -> Bool {
    sources[kind] ?? false
  }

  public var enabledSources: [SourceKind] {
    SourceKind.allCases.filter { isEnabled($0) }
  }

  // MARK: - Codable

  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case sources
    case showCopyNotification
    case showCodeInMenuBar
    case ignoredNotificationApps
    case keywords
    case codePattern
    case onboardingCompleted
    case didFinishWelcome
    case quickFillEnabled
    case quickFillPressesReturn
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 2

    if let raw = try container.decodeIfPresent([String: Bool].self, forKey: .sources) {
      var merged = AppSettings.defaultSources
      for (key, value) in raw {
        if let kind = SourceKind(rawValue: key) {
          merged[kind] = value
        }
      }
      sources = merged
    } else {
      sources = AppSettings.defaultSources
    }

    showCopyNotification = try container.decodeIfPresent(Bool.self, forKey: .showCopyNotification) ?? true
    showCodeInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showCodeInMenuBar) ?? true
    ignoredNotificationApps = try container.decodeIfPresent([String].self, forKey: .ignoredNotificationApps)
      ?? AppSettings.defaultIgnoredNotificationApps
    // 2.0 早期版本把 v1 的默认规则原样迁进了 v2；那不是用户的选择，读回来时换成 2.0 默认值。
    let decodedKeywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
    keywords = decodedKeywords.isEmpty || decodedKeywords == AppSettings.legacyDefaultKeywords
      ? AppSettings.defaultKeywords
      : decodedKeywords
    let decodedPattern = try container.decodeIfPresent(String.self, forKey: .codePattern) ?? ""
    codePattern = decodedPattern.isEmpty || decodedPattern == AppSettings.legacyDefaultCodePattern
      ? AppSettings.defaultCodePattern
      : decodedPattern
    // 2.0 早期版本写的是 `didFinishWelcome`，读回来时兼容它。
    onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted)
      ?? container.decodeIfPresent(Bool.self, forKey: .didFinishWelcome)
      ?? false
    quickFillEnabled = try container.decodeIfPresent(Bool.self, forKey: .quickFillEnabled) ?? false
    quickFillPressesReturn = try container.decodeIfPresent(
      Bool.self, forKey: .quickFillPressesReturn
    ) ?? false
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(schemaVersion, forKey: .schemaVersion)
    var raw: [String: Bool] = [:]
    for (kind, value) in sources {
      raw[kind.rawValue] = value
    }
    try container.encode(raw, forKey: .sources)
    try container.encode(showCopyNotification, forKey: .showCopyNotification)
    try container.encode(showCodeInMenuBar, forKey: .showCodeInMenuBar)
    try container.encode(ignoredNotificationApps, forKey: .ignoredNotificationApps)
    try container.encode(keywords, forKey: .keywords)
    try container.encode(codePattern, forKey: .codePattern)
    try container.encode(onboardingCompleted, forKey: .onboardingCompleted)
    try container.encode(quickFillEnabled, forKey: .quickFillEnabled)
    try container.encode(quickFillPressesReturn, forKey: .quickFillPressesReturn)
  }
}

// MARK: - 持久化

/// 设置的读写与 v1 迁移。
public enum AppSettingsStore {
  /// 从给定的 `UserDefaults` 载入设置；必要时执行 v1 → v2 迁移。
  public static func load(from defaults: UserDefaults) -> AppSettings {
    if let data = defaults.data(forKey: AppSettings.storageKey) {
      if let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
        return decoded
      }
      return AppSettings()
    }

    if let legacy = defaults.data(forKey: AppSettings.legacyStorageKey),
       let migrated = migrateV1(legacy) {
      save(migrated, to: defaults)
      defaults.removeObject(forKey: AppSettings.legacyStorageKey)
      return migrated
    }

    return AppSettings()
  }

  public static func save(_ settings: AppSettings, to defaults: UserDefaults) {
    guard let data = try? JSONEncoder().encode(settings) else {
      return
    }
    defaults.set(data, forKey: AppSettings.storageKey)
  }

  /// v1 JSON → v2 设置。无法解析时返回 nil。
  public static func migrateV1(_ data: Data) -> AppSettings? {
    guard let object = try? JSONSerialization.jsonObject(with: data),
          let dict = object as? [String: Any] else {
      return nil
    }

    var settings = AppSettings()
    settings.sources = [
      .messages: dict["monitorMessages"] as? Bool ?? true,
      .mail: dict["monitorMail"] as? Bool ?? true,
      .notificationCenter: dict["monitorSystemNotifications"] as? Bool ?? false
    ]
    settings.showCopyNotification = dict["showCopyNotification"] as? Bool ?? true

    // 只有用户改过的值才沿用；原封不动的 1.x 默认值换成 2.0 的默认值，
    // 后者是照着测试语料调出来的。
    if let csv = dict["keywordCSV"] as? String {
      let parts = csv
        .components(separatedBy: CharacterSet(charactersIn: ",\n，"))
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
      if !parts.isEmpty, parts != AppSettings.legacyDefaultKeywords {
        settings.keywords = parts
      }
    }

    if let regex = dict["codeRegex"] as? String,
       !regex.isEmpty,
       regex != AppSettings.legacyDefaultCodePattern {
      settings.codePattern = regex
    }

    if let ignoreTelegram = dict["ignoreTelegramNotifications"] as? Bool, ignoreTelegram == false {
      settings.ignoredNotificationApps = []
    }

    return settings
  }
}
