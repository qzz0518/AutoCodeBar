import Foundation

/// 抽取上下文。
public enum ExtractionContext: Sendable {
  case message
  case mail
}

/// 一次成功抽取的结果。
public struct Extraction: Equatable, Sendable {
  public let code: String
  public let keyword: String
  public let score: Int

  public init(code: String, keyword: String, score: Int) {
    self.code = code
    self.keyword = keyword
    self.score = score
  }
}

/// 基于关键词邻近度打分的验证码抽取器。
public struct CodeExtractor: @unchecked Sendable {
  public let rules: ExtractionRules

  public init(rules: ExtractionRules = .defaults) {
    self.rules = rules
  }

  /// 规范化后的搜索文本与主题区间。
  public struct SearchText {
    public let text: String
    /// 主题在 `text` 中的 UTF-16 区间；非邮件为 nil。
    public let subjectRange: NSRange?

    public init(text: String, subjectRange: NSRange?) {
      self.text = text
      self.subjectRange = subjectRange
    }
  }

  /// 构造搜索文本（邮件为 `subject + "\n" + body`）。
  public static func makeSearchText(text: String, subject: String?) -> SearchText {
    let body = TextNormalizer.normalize(text)
    guard let subject, !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return SearchText(text: body, subjectRange: nil)
    }
    let head = TextNormalizer.normalize(subject)
    guard !head.isEmpty else {
      return SearchText(text: body, subjectRange: nil)
    }
    let combined = body.isEmpty ? head : head + "\n" + body
    return SearchText(text: combined, subjectRange: NSRange(location: 0, length: (head as NSString).length))
  }

  public func extract(text: String, subject: String? = nil, context: ExtractionContext) -> Extraction? {
    let search = CodeExtractor.makeSearchText(text: text, subject: subject)
    return extract(search: search, context: context)
  }

  public func extract(search: SearchText, context: ExtractionContext) -> Extraction? {
    let ns = search.text as NSString
    guard ns.length > 0 else {
      return nil
    }

    let hits = keywordHits(in: search.text)
    guard !hits.isEmpty else {
      return nil
    }

    var candidates = candidateRanges(in: search.text, ns: ns)
    guard !candidates.isEmpty else {
      return nil
    }

    // 硬过滤：年份、金额单位、货币前缀。
    candidates = candidates.filter { !isHardFiltered($0, ns: ns) }
    guard !candidates.isEmpty else {
      return nil
    }

    // 硬过滤：邮件主题里的候选，且正文里另有候选。
    if context == .mail, let subjectRange = search.subjectRange {
      let outside = candidates.filter { NSIntersectionRange($0, subjectRange).length == 0 }
      if !outside.isEmpty {
        candidates = outside
      }
    }

    // mail 特例：正文无关键词但主题有关键词时，邻近度固定为 50。
    var fixedProximity: Int?
    if context == .mail, let subjectRange = search.subjectRange {
      let bodyHits = hits.filter { NSIntersectionRange($0.range, subjectRange).length == 0 }
      if bodyHits.isEmpty {
        fixedProximity = 50
      }
    }

    let distanceLimit = context == .mail ? 600 : 120
    let cjkHeavy = CodeExtractor.isCJKHeavy(search.text)

    var best: (score: Int, candidate: NSRange, keyword: String, after: Bool)?

    for candidate in candidates {
      guard let nearest = nearestHit(to: candidate, hits: hits) else {
        continue
      }
      if fixedProximity == nil && nearest.distance > distanceLimit {
        continue
      }

      let proximity = fixedProximity ?? (100 - min(nearest.distance, 100))
      let after = candidate.location >= nearest.hit.range.location + nearest.hit.range.length
      var score = proximity
      score += after ? 15 : 0
      score += shapeScore(candidate, ns: ns, cjkHeavy: cjkHeavy)
      score += leadScore(candidate, ns: ns)
      score += lineScore(candidate, ns: ns)
      score += contextPenalty(candidate, ns: ns)

      guard score >= 40 else {
        continue
      }

      if let current = best {
        if score > current.score
          || (score == current.score && after && !current.after)
          || (score == current.score && after == current.after && candidate.location < current.candidate.location) {
          best = (score, candidate, nearest.hit.keyword, after)
        }
      } else {
        best = (score, candidate, nearest.hit.keyword, after)
      }
    }

    guard let winner = best else {
      return nil
    }

    let raw = ns.substring(with: winner.candidate)
    return Extraction(code: CodeExtractor.normalizeCode(raw), keyword: winner.keyword, score: winner.score)
  }

  // MARK: - 关键词

  struct KeywordHit {
    let range: NSRange
    let keyword: String
  }

  private func keywordHits(in text: String) -> [KeywordHit] {
    var hits: [KeywordHit] = []
    let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    for keyword in rules.keywords {
      var searchStart = text.startIndex
      while searchStart < text.endIndex,
            let found = text.range(of: keyword, options: options, range: searchStart..<text.endIndex) {
        hits.append(KeywordHit(range: NSRange(found, in: text), keyword: keyword))
        searchStart = found.isEmpty ? text.index(after: found.lowerBound) : found.upperBound
      }
    }
    return hits
  }

  private func nearestHit(to candidate: NSRange, hits: [KeywordHit]) -> (hit: KeywordHit, distance: Int)? {
    var best: (hit: KeywordHit, distance: Int)?
    let candStart = candidate.location
    let candEnd = candidate.location + candidate.length
    for hit in hits {
      let kwStart = hit.range.location
      let kwEnd = hit.range.location + hit.range.length
      let distance: Int
      if candStart >= kwEnd {
        distance = candStart - kwEnd
      } else if kwStart >= candEnd {
        distance = kwStart - candEnd
      } else {
        distance = 0
      }
      if let current = best, distance >= current.distance {
        continue
      }
      best = (hit, distance)
    }
    return best
  }

  // MARK: - 候选

  private func candidateRanges(in text: String, ns: NSString) -> [NSRange] {
    let full = NSRange(location: 0, length: ns.length)
    return rules.candidateRegex.matches(in: text, range: full)
      .map(\.range)
      .filter { $0.length > 0 && CodeExtractor.passesShapeCheck(ns.substring(with: $0)) }
  }

  /// 固定后校验：去掉连字符后 4–8 个字母数字、至少 1 个数字、至多 1 个连字符且不在首尾。
  static func passesShapeCheck(_ raw: String) -> Bool {
    let hyphens = raw.filter { $0 == "-" }.count
    guard hyphens <= 1 else {
      return false
    }
    if hyphens == 1, raw.hasPrefix("-") || raw.hasSuffix("-") {
      return false
    }
    let stripped = raw.replacingOccurrences(of: "-", with: "")
    guard stripped.count >= 4, stripped.count <= 8 else {
      return false
    }
    guard stripped.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
      return false
    }
    return stripped.contains(where: { $0.isNumber })
  }

  // MARK: - 硬过滤

  private static let yearRegex = try? NSRegularExpression(pattern: "^(?:19|20)\\d{2}$")

  private static let yearSuffix = "年"

  private static let unitWords: [String] = [
    "%", "元", "块", "￥", "¥", "$", "美元", "MB", "GB", "KB", "km", "kg",
    "分钟", "分", "秒", "小时", "天",
    "min", "mins", "minute", "minutes", "sec", "secs", "second", "seconds",
    "hour", "hours", "day", "days"
  ]

  private static let currencyPrefixes: Set<Character> = ["¥", "￥", "$", "€", "£"]

  private func isHardFiltered(_ range: NSRange, ns: NSString) -> Bool {
    let raw = ns.substring(with: range)
    if isYearLike(raw, range: range, ns: ns) {
      return true
    }
    if hasUnitSuffix(range, ns: ns) {
      return true
    }
    if hasCurrencyPrefix(range, ns: ns) {
      return true
    }
    return false
  }

  private func isYearLike(_ raw: String, range: NSRange, ns: NSString) -> Bool {
    guard let regex = CodeExtractor.yearRegex else {
      return false
    }
    let rawRange = NSRange(location: 0, length: (raw as NSString).length)
    guard regex.firstMatch(in: raw, range: rawRange) != nil else {
      return false
    }

    let end = range.location + range.length
    // 后一个非空白字符是「年」
    var index = end
    while index < ns.length, CodeExtractor.isWhitespace(ns.character(at: index)) {
      index += 1
    }
    if index < ns.length,
       ns.substring(with: NSRange(location: index, length: 1)) == CodeExtractor.yearSuffix {
      return true
    }
    // 后一个字符 ∈ - / . 且再后一个是数字
    if end + 1 < ns.length {
      let next = ns.substring(with: NSRange(location: end, length: 1))
      let after = ns.substring(with: NSRange(location: end + 1, length: 1))
      if ["-", "/", "."].contains(next), after.first?.isNumber == true {
        return true
      }
    }
    // 前一个字符 ∈ - / . 且再前一个是数字
    if range.location >= 2 {
      let prev = ns.substring(with: NSRange(location: range.location - 1, length: 1))
      let before = ns.substring(with: NSRange(location: range.location - 2, length: 1))
      if ["-", "/", "."].contains(prev), before.first?.isNumber == true {
        return true
      }
    }
    return false
  }

  private func hasUnitSuffix(_ range: NSRange, ns: NSString) -> Bool {
    var index = range.location + range.length
    guard index < ns.length else {
      return false
    }
    if ns.character(at: index) == 32 {
      index += 1
    }
    guard index < ns.length else {
      return false
    }
    let tail = ns.substring(with: NSRange(location: index, length: min(12, ns.length - index)))
    for unit in CodeExtractor.unitWords {
      let isASCIIWord = unit.allSatisfy { $0.isASCII && $0.isLetter }
      if isASCIIWord {
        guard tail.lowercased().hasPrefix(unit.lowercased()) else {
          continue
        }
        guard let nextIndex = tail.index(tail.startIndex, offsetBy: unit.count, limitedBy: tail.endIndex) else {
          return true
        }
        if nextIndex == tail.endIndex {
          return true
        }
        let next = tail[nextIndex]
        if !(next.isASCII && (next.isLetter || next.isNumber)) {
          return true
        }
      } else if tail.hasPrefix(unit) {
        return true
      }
    }
    return false
  }

  private func hasCurrencyPrefix(_ range: NSRange, ns: NSString) -> Bool {
    var index = range.location - 1
    guard index >= 0 else {
      return false
    }
    if ns.character(at: index) == 32 {
      index -= 1
    }
    guard index >= 0 else {
      return false
    }
    let char = ns.substring(with: NSRange(location: index, length: 1))
    guard let first = char.first else {
      return false
    }
    return CodeExtractor.currencyPrefixes.contains(first)
  }

  // MARK: - 打分

  private func shapeScore(_ range: NSRange, ns: NSString, cjkHeavy: Bool) -> Int {
    let raw = ns.substring(with: range)
    let digitsOnly = raw.allSatisfy { $0.isNumber }
    if digitsOnly {
      switch raw.count {
      case 6: return 10
      case 4, 5, 7, 8: return 5
      default: return 0
      }
    }
    return cjkHeavy ? -20 : 0
  }

  private static let leadMarkers: [String] = [":", "：", "是", "为", "is"]

  private func leadScore(_ range: NSRange, ns: NSString) -> Int {
    var collected: [String] = []
    var index = range.location - 1
    while index >= 0 && collected.count < 3 {
      let unit = ns.character(at: index)
      if !CodeExtractor.isWhitespace(unit) {
        collected.append(ns.substring(with: NSRange(location: index, length: 1)))
      }
      index -= 1
    }
    guard !collected.isEmpty else {
      return 0
    }
    let prefix = collected.reversed().joined().lowercased()
    return CodeExtractor.leadMarkers.contains(where: { prefix.contains($0.lowercased()) }) ? 8 : 0
  }

  private func lineScore(_ range: NSRange, ns: NSString) -> Int {
    var index = range.location - 1
    while index >= 0 {
      let unit = ns.character(at: index)
      if unit == 10 {
        break
      }
      guard CodeExtractor.isIgnorableAroundLine(unit) else {
        return 0
      }
      index -= 1
    }

    index = range.location + range.length
    while index < ns.length {
      let unit = ns.character(at: index)
      if unit == 10 {
        break
      }
      guard CodeExtractor.isIgnorableAroundLine(unit) else {
        return 0
      }
      index += 1
    }
    return 10
  }

  private static let contextMarkers: [String] = [
    "尾号", "末位", "卡号", "账号", "工单", "订单", "单号", "编号", "流水", "房号", "门牌"
  ]

  private func contextPenalty(_ range: NSRange, ns: NSString) -> Int {
    let start = max(0, range.location - 4)
    guard start < range.location else {
      return 0
    }
    let prefix = ns.substring(with: NSRange(location: start, length: range.location - start))
    return CodeExtractor.contextMarkers.contains(where: { prefix.contains($0) }) ? -40 : 0
  }

  // MARK: - 工具

  private static func isWhitespace(_ unit: unichar) -> Bool {
    unit == 32 || unit == 9 || unit == 10 || unit == 13
  }

  private static func isIgnorableAroundLine(_ unit: unichar) -> Bool {
    if isWhitespace(unit) {
      return true
    }
    guard let scalar = Unicode.Scalar(unit) else {
      return false
    }
    return CharacterSet.punctuationCharacters.contains(scalar)
      || CharacterSet.symbols.contains(scalar)
  }

  static func isCJKHeavy(_ text: String) -> Bool {
    var letters = 0
    var cjk = 0
    for scalar in text.unicodeScalars where scalar.properties.isAlphabetic {
      letters += 1
      if isCJKScalar(scalar) {
        cjk += 1
      }
    }
    guard letters > 0 else {
      return false
    }
    return Double(cjk) / Double(letters) >= 0.30
  }

  private static func isCJKScalar(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.value {
    case 0x3040...0x30FF,      // 平假名 / 片假名
         0x31F0...0x31FF,      // 片假名扩展
         0x3400...0x4DBF,      // CJK 扩展 A
         0x4E00...0x9FFF,      // CJK 基本区
         0xAC00...0xD7AF,      // 谚文音节
         0xF900...0xFAFF,      // CJK 兼容
         0xFF66...0xFF9D,      // 半角片假名
         0x1100...0x11FF,      // 谚文字母
         0x20000...0x2FA1F:    // CJK 扩展 B+
      return true
    default:
      return false
    }
  }

  /// 输出规范化。
  static func normalizeCode(_ raw: String) -> String {
    if let match = raw.range(of: "^[A-Za-z]-(\\d{4,8})$", options: .regularExpression), match == raw.startIndex..<raw.endIndex {
      return String(raw.dropFirst(2))
    }
    if raw.range(of: "^\\d+-\\d+$", options: .regularExpression) != nil {
      return raw.replacingOccurrences(of: "-", with: "")
    }
    return raw
  }
}
