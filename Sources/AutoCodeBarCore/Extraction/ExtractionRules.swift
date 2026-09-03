import Foundation

/// 抽取规则：关键词集合 + 编译好的候选正则。值类型，编译一次后重复使用。
public struct ExtractionRules: @unchecked Sendable {
  public let keywords: [String]
  public let pattern: String
  let candidateRegex: NSRegularExpression

  public init(keywords: [String], pattern: String) throws {
    let cleaned = keywords
      .map { TextNormalizer.normalizeKeyword($0) }
      .filter { !$0.isEmpty }
    self.keywords = cleaned.isEmpty ? AppSettings.defaultKeywords : cleaned
    self.pattern = pattern
    self.candidateRegex = try ExtractionRules.compile(pattern: pattern)
  }

  /// 用户正则外面套上字母数字边界。
  static func compile(pattern: String) throws -> NSRegularExpression {
    // 先单独编译原始正则，让错误信息指向用户输入本身。
    _ = try NSRegularExpression(pattern: pattern)
    return try NSRegularExpression(pattern: "(?<![A-Za-z0-9])(?:\(pattern))(?![A-Za-z0-9])")
  }

  /// 校验正则；有效返回 nil，无效返回错误描述。
  public static func validationError(for pattern: String) -> String? {
    do {
      _ = try compile(pattern: pattern)
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  public static let defaults: ExtractionRules = {
    // 默认值是常量，编译必定成功。
    try! ExtractionRules(keywords: AppSettings.defaultKeywords, pattern: AppSettings.defaultCodePattern)
  }()

  /// 从设置构造；正则无效时抛出。
  public static func make(from settings: AppSettings) throws -> ExtractionRules {
    try ExtractionRules(keywords: settings.keywords, pattern: settings.codePattern)
  }
}
