import Foundation
import Testing

@testable import AutoCodeBarCore

@Suite("AppSettings")
struct AppSettingsTests {
  private func makeDefaults(_ name: String) -> UserDefaults {
    let suite = "AutoCodeBarTests.\(name).\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite) ?? .standard
    defaults.removePersistentDomain(forName: suite)
    return defaults
  }

  @Test("默认值")
  func defaultsAreSane() {
    let settings = AppSettings()
    #expect(settings.schemaVersion == 2)
    #expect(settings.isEnabled(.messages))
    #expect(settings.isEnabled(.mail))
    #expect(!settings.isEnabled(.notificationCenter))
    #expect(settings.showCopyNotification)
    #expect(settings.showCodeInMenuBar)
    #expect(!settings.onboardingCompleted)
    #expect(settings.keywords.contains("验证码"))
    #expect(settings.codePattern == AppSettings.defaultCodePattern)
    #expect(settings.ignoredNotificationApps.contains("ru.keepcoder.telegram"))
    #expect(!settings.quickFillEnabled)
    #expect(!settings.quickFillPressesReturn)
  }

  @Test("旧 JSON 没有一键填入的两个键时都为 false")
  func quickFillDefaultsWhenAbsent() throws {
    let json = Data(#"{"schemaVersion": 2}"#.utf8)
    let settings = try JSONDecoder().decode(AppSettings.self, from: json)
    #expect(!settings.quickFillEnabled)
    #expect(!settings.quickFillPressesReturn)
  }

  @Test("一键填入的两个键往返保值")
  func quickFillRoundTrip() throws {
    var settings = AppSettings()
    settings.quickFillEnabled = true
    settings.quickFillPressesReturn = true
    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
    #expect(decoded.quickFillEnabled)
    #expect(decoded.quickFillPressesReturn)
    #expect(decoded == settings)
  }

  @Test("缺字段解码回落默认值")
  func partialDecoding() throws {
    let json = Data(#"{"showCopyNotification": false}"#.utf8)
    let settings = try JSONDecoder().decode(AppSettings.self, from: json)
    #expect(!settings.showCopyNotification)
    #expect(settings.showCodeInMenuBar)
    #expect(settings.isEnabled(.messages))
    #expect(settings.keywords == AppSettings.defaultKeywords)
    #expect(settings.codePattern == AppSettings.defaultCodePattern)
  }

  @Test("部分 sources 字典与默认值合并")
  func partialSources() throws {
    let json = Data(#"{"sources": {"mail": false}}"#.utf8)
    let settings = try JSONDecoder().decode(AppSettings.self, from: json)
    #expect(settings.isEnabled(.messages))
    #expect(!settings.isEnabled(.mail))
  }

  @Test("往返编解码")
  func roundTrip() throws {
    var settings = AppSettings()
    settings.keywords = ["验证码", "code"]
    settings.codePattern = "\\d{6}"
    settings.onboardingCompleted = true
    settings.sources[.notificationCenter] = true
    let data = try JSONEncoder().encode(settings)
    #expect(try JSONDecoder().decode(AppSettings.self, from: data) == settings)
  }

  @Test("v1 → v2 迁移")
  func migration() throws {
    let defaults = makeDefaults("migration")
    let legacy: [String: Any] = [
      "monitorMessages": true,
      "monitorMail": false,
      "monitorSystemNotifications": true,
      "monitorOwnNotifications": true,
      "suppressDuplicates": true,
      "maxEventHistory": 30,
      "showCopyNotification": false,
      "keywordCSV": "验证码, code\nOTP，动态码",
      "codeRegex": "\\d{4,8}",
      "ignoreTelegramNotifications": true
    ]
    defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: AppSettings.legacyStorageKey)

    let settings = AppSettingsStore.load(from: defaults)
    #expect(settings.schemaVersion == 2)
    #expect(settings.isEnabled(.messages))
    #expect(!settings.isEnabled(.mail))
    #expect(settings.isEnabled(.notificationCenter))
    #expect(!settings.showCopyNotification)
    #expect(settings.keywords == ["验证码", "code", "OTP", "动态码"])
    #expect(settings.codePattern == "\\d{4,8}")
    #expect(settings.ignoredNotificationApps == AppSettings.defaultIgnoredNotificationApps)
    #expect(defaults.data(forKey: AppSettings.legacyStorageKey) == nil)
    #expect(defaults.data(forKey: AppSettings.storageKey) != nil)
  }

  @Test("v1 迁移：ignoreTelegramNotifications = false 清空忽略列表")
  func migrationWithoutTelegramIgnore() throws {
    let defaults = makeDefaults("migration-telegram")
    let legacy: [String: Any] = ["ignoreTelegramNotifications": false]
    defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: AppSettings.legacyStorageKey)
    let settings = AppSettingsStore.load(from: defaults)
    #expect(settings.ignoredNotificationApps.isEmpty)
  }

  @Test("v1 迁移：原封不动的 v1 默认关键词与正则改用 v2 默认值")
  func migrationDropsLegacyDefaults() throws {
    let defaults = makeDefaults("migration-legacy-defaults")
    let legacy: [String: Any] = [
      "keywordCSV": AppSettings.legacyDefaultKeywords.joined(separator: ", "),
      "codeRegex": AppSettings.legacyDefaultCodePattern
    ]
    defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: AppSettings.legacyStorageKey)

    let settings = AppSettingsStore.load(from: defaults)
    #expect(settings.keywords == AppSettings.defaultKeywords)
    #expect(settings.codePattern == AppSettings.defaultCodePattern)
  }

  @Test("v1 迁移：用户改过的关键词与正则原样保留")
  func migrationKeepsCustomRules() throws {
    let defaults = makeDefaults("migration-custom")
    let legacy: [String: Any] = [
      "keywordCSV": "验证码, 我的关键词",
      "codeRegex": "\\d{6}"
    ]
    defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: AppSettings.legacyStorageKey)

    let settings = AppSettingsStore.load(from: defaults)
    #expect(settings.keywords == ["验证码", "我的关键词"])
    #expect(settings.codePattern == "\\d{6}")
  }

  @Test("兼容解码早期的 didFinishWelcome 字段")
  func legacyOnboardingFlag() throws {
    let old = try JSONDecoder().decode(
      AppSettings.self,
      from: Data(#"{"didFinishWelcome": true}"#.utf8)
    )
    #expect(old.onboardingCompleted)

    // 新字段优先。
    let both = try JSONDecoder().decode(
      AppSettings.self,
      from: Data(#"{"didFinishWelcome": true, "onboardingCompleted": false}"#.utf8)
    )
    #expect(!both.onboardingCompleted)
  }

  @Test("编码后只写新字段名")
  func encodesNewKeyOnly() throws {
    var settings = AppSettings()
    settings.onboardingCompleted = true
    let json = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(settings))
    let dict = try #require(json as? [String: Any])
    #expect(dict["onboardingCompleted"] as? Bool == true)
    #expect(dict["didFinishWelcome"] == nil)
  }

  @Test("v2 解码：残留的 v1 默认关键词与正则换成 v2 默认值")
  func decodeReplacesLeftoverLegacyDefaults() throws {
    let json: [String: Any] = [
      "schemaVersion": 2,
      "keywords": AppSettings.legacyDefaultKeywords,
      "codePattern": AppSettings.legacyDefaultCodePattern
    ]
    let data = try JSONSerialization.data(withJSONObject: json)
    let settings = try JSONDecoder().decode(AppSettings.self, from: data)
    #expect(settings.keywords == AppSettings.defaultKeywords)
    #expect(settings.codePattern == AppSettings.defaultCodePattern)

    let custom: [String: Any] = ["schemaVersion": 2, "keywords": ["取件码"], "codePattern": "[0-9]{6}"]
    let customSettings = try JSONDecoder().decode(
      AppSettings.self, from: try JSONSerialization.data(withJSONObject: custom)
    )
    #expect(customSettings.keywords == ["取件码"])
    #expect(customSettings.codePattern == "[0-9]{6}")
  }

  @Test("存取往返")
  func storeRoundTrip() {
    let defaults = makeDefaults("store")
    var settings = AppSettings()
    settings.onboardingCompleted = true
    AppSettingsStore.save(settings, to: defaults)
    #expect(AppSettingsStore.load(from: defaults).onboardingCompleted)
  }
}
