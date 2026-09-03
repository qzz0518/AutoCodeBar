import Foundation
import Testing

@testable import AutoCodeBarCore

@MainActor
private struct Harness {
  let clipboard = NoopClipboard()
  let pipeline: CodePipeline
  private let clock: () -> Date

  init(now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_000_000) }) {
    clock = now
    let clipboard = self.clipboard
    pipeline = CodePipeline(
      extractor: CodeExtractor(),
      clipboard: clipboard,
      deduplicator: Deduplicator(window: 300, now: now),
      ignoredNotificationApps: AppSettings.defaultIgnoredNotificationApps,
      ownBundleIdentifier: "dev.qiuzezheng.AutoCodeBar",
      now: now
    )
  }

  var now: Date { clock() }

  func candidate(
    kind: SourceKind = .messages,
    identity: String = "rowid:1",
    sender: String? = "10086",
    text: String,
    offset: TimeInterval = 0
  ) -> Candidate {
    Candidate(
      kind: kind,
      identity: identity,
      senderIdentifier: sender,
      senderDisplay: sender,
      subject: nil,
      text: text,
      receivedAt: now.addingTimeInterval(offset)
    )
  }
}

@Suite("CodePipeline")
@MainActor
struct CodePipelineTests {
  @Test("正常处理：复制一次并进历史")
  func happyPath() throws {
    let harness = Harness()
    var received: [(CodeEvent, Bool)] = []
    harness.pipeline.onEvent = { event, copied in received.append((event, copied)) }

    let event = try #require(harness.pipeline.handle(harness.candidate(text: "【京东】验证码 183920，5 分钟内有效。")))
    #expect(event.code == "183920")
    #expect(event.senderDisplay == "10086")
    #expect(event.preview.contains("183920"))
    #expect(harness.clipboard.copied == ["183920"])
    #expect(harness.pipeline.history.events.count == 1)
    #expect(received.count == 1)
    #expect(received.first?.1 == true)
  }

  @Test("跨源 300 秒去重")
  func crossSourceDedup() {
    let harness = Harness()
    #expect(harness.pipeline.handle(harness.candidate(text: "验证码 482913")) != nil)
    let fromNotification = harness.candidate(
      kind: .notificationCenter,
      identity: "rec:9",
      sender: "com.apple.mobilesms",
      text: "验证码 482913"
    )
    #expect(harness.pipeline.handle(fromNotification) == nil)
    #expect(harness.clipboard.copied == ["482913"])
    #expect(harness.pipeline.history.events.count == 1)
  }

  @Test("陈旧候选被丢弃")
  func staleDiscarded() {
    let harness = Harness()
    #expect(harness.pipeline.handle(harness.candidate(text: "验证码 482913", offset: -601)) == nil)
    #expect(harness.clipboard.copied.isEmpty)
  }

  @Test("自身 bundle id 被忽略")
  func ignoresOwnBundle() {
    let harness = Harness()
    let candidate = harness.candidate(
      kind: .notificationCenter,
      sender: "dev.qiuzezheng.autocodebar",
      text: "AutoCodeBar 验证码 482913"
    )
    #expect(harness.pipeline.handle(candidate) == nil)
  }

  @Test("「已复制验证码」文本被忽略")
  func ignoresSelfEcho() {
    let harness = Harness()
    let candidate = harness.candidate(
      kind: .notificationCenter,
      sender: "com.example.other",
      text: "已复制验证码 482913\n来自 京东 · 短信"
    )
    #expect(harness.pipeline.handle(candidate) == nil)
  }

  @Test("忽略应用列表生效，且只作用于通知源")
  func ignoredApps() {
    let harness = Harness()
    let telegram = harness.candidate(
      kind: .notificationCenter,
      sender: "ru.keepcoder.telegram",
      text: "Login code: 48213"
    )
    #expect(harness.pipeline.handle(telegram) == nil)

    let sms = harness.candidate(kind: .messages, sender: "ru.keepcoder.telegram", text: "Login code: 48213")
    #expect(harness.pipeline.handle(sms) != nil)
  }

  @Test("历史上限 20 条，最新在前")
  func historyLimit() {
    let harness = Harness()
    for index in 0..<25 {
      let code = String(format: "%06d", 100_000 + index)
      _ = harness.pipeline.handle(harness.candidate(identity: "rowid:\(index)", text: "验证码 \(code)"))
    }
    #expect(harness.pipeline.history.events.count == 20)
    #expect(harness.pipeline.history.events.first?.code == "100024")
    #expect(harness.pipeline.history.events.last?.code == "100005")
  }

  @Test("剪贴板失败仍记入历史，但标记未复制")
  func clipboardFailure() throws {
    let harness = Harness()
    harness.clipboard.succeeds = false
    var copiedFlag: Bool?
    harness.pipeline.onEvent = { _, copied in copiedFlag = copied }
    _ = try #require(harness.pipeline.handle(harness.candidate(text: "验证码 482913")))
    #expect(copiedFlag == false)
    #expect(harness.pipeline.history.events.count == 1)
  }

  @Test("无验证码不产生事件")
  func noCode() {
    let harness = Harness()
    #expect(harness.pipeline.handle(harness.candidate(text: "订单号 2025090412345678 已发货")) == nil)
    #expect(harness.clipboard.copied.isEmpty)
  }

  @Test("邮件走 subject + body")
  func mailCandidate() throws {
    let harness = Harness()
    let candidate = Candidate(
      kind: .mail,
      identity: "/tmp/a.emlx",
      senderIdentifier: "no-reply@github.com",
      senderDisplay: "GitHub",
      subject: "Your GitHub launch code",
      text: "Continue signing up for GitHub by entering the code below:\n\n918273\n\nOpen GitHub",
      receivedAt: harness.now
    )
    let event = try #require(harness.pipeline.handle(candidate))
    #expect(event.code == "918273")
    #expect(event.preview.hasPrefix("Your GitHub launch code"))
  }

  @Test("移除与清空历史")
  func mutateHistory() throws {
    let harness = Harness()
    let first = try #require(harness.pipeline.handle(harness.candidate(text: "验证码 482913")))
    _ = harness.pipeline.handle(harness.candidate(identity: "rowid:2", text: "验证码 771122"))
    harness.pipeline.remove(first)
    #expect(harness.pipeline.history.events.count == 1)
    harness.pipeline.clearHistory()
    #expect(harness.pipeline.history.isEmpty)
  }
}
