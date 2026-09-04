import Foundation
import Testing

@testable import AutoCodeBar
@testable import AutoCodeBarCore

/// 记录被交给填入会话的事件，不碰 AX、不开面板。
@MainActor
private final class SpyQuickFill: QuickFillPresenting {
  var pressesReturn = false
  var offered: [CodeEvent] = []
  var cancelCount = 0

  func offer(_ event: CodeEvent) {
    offered.append(event)
  }

  func cancel() {
    cancelCount += 1
  }
}

@Suite("一键填入")
@MainActor
struct QuickFillTests {
  /// 每个用例一块独立的偏好域，`AppState` 的写回不会相互串味。
  private func makeState(trusted: Bool, spy: SpyQuickFill) -> AppState {
    let suite = "AutoCodeBarTests.quickFill.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite) ?? .standard
    defaults.removePersistentDomain(forName: suite)
    return AppState(
      updater: AppUpdater(),
      defaults: defaults,
      accessibilityProbe: { trusted },
      quickFill: spy
    )
  }

  private func makeEvent(_ code: String = "482913") -> CodeEvent {
    CodeEvent(
      code: code,
      kind: .messages,
      senderDisplay: "Test",
      preview: "preview",
      receivedAt: Date()
    )
  }

  @Test("开关关闭时不开会话")
  func disabledDoesNotOffer() {
    let spy = SpyQuickFill()
    let state = makeState(trusted: true, spy: spy)
    state.handle(event: makeEvent(), copied: true)
    #expect(spy.offered.isEmpty)
  }

  @Test("开关打开但未授权时不开会话")
  func untrustedDoesNotOffer() {
    let spy = SpyQuickFill()
    let state = makeState(trusted: false, spy: spy)
    state.settings.quickFillEnabled = true
    state.handle(event: makeEvent(), copied: true)
    #expect(spy.offered.isEmpty)
  }

  @Test("开关打开且已授权时开一次会话")
  func enabledAndTrustedOffers() {
    let spy = SpyQuickFill()
    let state = makeState(trusted: true, spy: spy)
    state.settings.quickFillEnabled = true
    state.handle(event: makeEvent("135790"), copied: true)
    #expect(spy.offered.count == 1)
    #expect(spy.offered.first?.code == "135790")
  }

  @Test("关掉开关会取消进行中的会话")
  func disablingCancels() {
    let spy = SpyQuickFill()
    let state = makeState(trusted: true, spy: spy)
    state.settings.quickFillEnabled = true
    state.handle(event: makeEvent(), copied: true)
    state.settings.quickFillEnabled = false
    #expect(spy.cancelCount == 1)
  }

  @Test("回车开关同步给会话")
  func pressesReturnSyncs() {
    let spy = SpyQuickFill()
    let state = makeState(trusted: true, spy: spy)
    #expect(!spy.pressesReturn)
    state.settings.quickFillPressesReturn = true
    #expect(spy.pressesReturn)
    state.settings.quickFillPressesReturn = false
    #expect(!spy.pressesReturn)
  }

  @Test("暂停监听会取消会话")
  func pauseCancels() {
    let spy = SpyQuickFill()
    let state = makeState(trusted: true, spy: spy)
    state.settings.quickFillEnabled = true
    state.handle(event: makeEvent(), copied: true)
    state.pause()
    #expect(spy.cancelCount == 1)
  }
}
