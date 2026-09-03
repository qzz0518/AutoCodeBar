import Foundation

/// 候选 → 验证码事件的处理管线。
@MainActor
public final class CodePipeline {
  /// 陈旧阈值。
  public static let staleInterval: TimeInterval = 600

  public var extractor: CodeExtractor
  public var ignoredNotificationApps: Set<String>
  /// 事件回调：`(事件, 是否成功写入剪贴板)`。
  public var onEvent: ((CodeEvent, Bool) -> Void)?

  public private(set) var history = History()

  private let clipboard: Clipboard
  private let deduplicator: Deduplicator
  private let now: () -> Date
  private let ownBundleIdentifier: String

  public init(
    extractor: CodeExtractor = CodeExtractor(),
    clipboard: Clipboard,
    deduplicator: Deduplicator = Deduplicator(),
    ignoredNotificationApps: [String] = AppSettings.defaultIgnoredNotificationApps,
    ownBundleIdentifier: String = Bundle.main.bundleIdentifier ?? "dev.qiuzezheng.AutoCodeBar",
    now: @escaping () -> Date = Date.init
  ) {
    self.extractor = extractor
    self.clipboard = clipboard
    self.deduplicator = deduplicator
    self.ignoredNotificationApps = CodePipeline.normalizeIgnoreList(ignoredNotificationApps)
    self.ownBundleIdentifier = ownBundleIdentifier.lowercased()
    self.now = now
  }

  public func updateIgnoredNotificationApps(_ apps: [String]) {
    ignoredNotificationApps = CodePipeline.normalizeIgnoreList(apps)
  }

  public static func normalizeIgnoreList(_ apps: [String]) -> Set<String> {
    Set(apps
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .filter { !$0.isEmpty })
  }

  @discardableResult
  public func handle(_ candidate: Candidate) -> CodeEvent? {
    guard now().timeIntervalSince(candidate.receivedAt) <= CodePipeline.staleInterval else {
      return nil
    }
    guard !shouldIgnore(candidate) else {
      return nil
    }

    let context: ExtractionContext = candidate.kind == .mail ? .mail : .message
    let search = CodeExtractor.makeSearchText(text: candidate.text, subject: candidate.subject)
    guard let extraction = extractor.extract(search: search, context: context) else {
      return nil
    }
    guard deduplicator.accept(extraction.code) else {
      return nil
    }

    let copied = clipboard.copy(extraction.code)
    let event = CodeEvent(
      code: extraction.code,
      kind: candidate.kind,
      senderDisplay: candidate.senderDisplay ?? SenderDisplay.unknown,
      preview: TextNormalizer.singleLine(search.text),
      receivedAt: candidate.receivedAt
    )
    history.insert(event)
    onEvent?(event, copied)
    return event
  }

  public func remove(_ event: CodeEvent) {
    history.remove(id: event.id)
  }

  public func clearHistory() {
    history.clear()
  }

  // MARK: - 忽略规则

  private func shouldIgnore(_ candidate: Candidate) -> Bool {
    if let identifier = candidate.senderIdentifier?.lowercased(), identifier == ownBundleIdentifier {
      return true
    }
    if candidate.kind == .notificationCenter,
       let identifier = candidate.senderIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
       ignoredNotificationApps.contains(identifier) {
      return true
    }
    if candidate.text.trimmingCharacters(in: .whitespacesAndNewlines)
      .hasPrefix(L10n.text("已复制验证码", table: "Core")) {
      return true
    }
    return false
  }
}
