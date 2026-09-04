import AppKit
import ApplicationServices
import Foundation

import AutoCodeBarCore

/// 填入会话的对外接口。`AppState` 只认这个协议，测试塞 spy。
@MainActor
protocol QuickFillPresenting: AnyObject {
  var pressesReturn: Bool { get set }
  func offer(_ event: CodeEvent)
  func cancel()
}

/// 验证码到达后开一个 60 秒的填入会话：每 250ms 看一眼前台应用的聚焦元素，
/// 是输入框就把卡片贴上去，用户点一下才真正键入。
///
/// 不做盲敲——字只会落在用户点卡片那一刻聚焦的输入框里。
@MainActor
final class QuickFillController: QuickFillPresenting {
  var pressesReturn = false

  private let sender: KeystrokeSender
  private let probe: @Sendable (pid_t, CGFloat) -> FocusedField?
  private let sessionLength: TimeInterval
  private let pollInterval: TimeInterval
  private let panel = QuickFillPanel()

  /// AX 调用可能要等到超时，不能占着主线程。
  private let queue = DispatchQueue(
    label: "cc.zerah.AutoCodeBar.quickfill",
    qos: .userInitiated
  )

  private var session: (event: CodeEvent, deadline: Date)?
  private var timer: Timer?
  /// 上一次探测还没回来：跳过这一拍，不让请求堆积。
  private var isProbing = false
  private let ownPID = ProcessInfo.processInfo.processIdentifier
  /// `NSScreen` 只在主线程读；后台探测要的主屏高度缓存在这里。
  private var primaryScreenHeight: CGFloat
  private var observers: [NSObjectProtocol] = []

  init(
    sender: KeystrokeSender = CGEventKeystrokeSender(),
    probe: @escaping @Sendable (pid_t, CGFloat) -> FocusedField? = {
      FocusProbe.current(excludingPID: $0, primaryScreenHeight: $1)
    },
    sessionLength: TimeInterval = 60,
    pollInterval: TimeInterval = 0.25
  ) {
    self.sender = sender
    self.probe = probe
    self.sessionLength = sessionLength
    self.pollInterval = pollInterval
    self.primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0

    let workspace = NSWorkspace.shared.notificationCenter
    observers.append(
      workspace.addObserver(
        forName: NSWorkspace.didActivateApplicationNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.tick()
        }
      }
    )
    observers.append(
      NotificationCenter.default.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        }
      }
    )
  }

  deinit {
    let workspace = NSWorkspace.shared.notificationCenter
    for observer in observers {
      workspace.removeObserver(observer)
      NotificationCenter.default.removeObserver(observer)
    }
  }

  // MARK: - 会话

  /// 新验证码替换旧会话。
  func offer(_ event: CodeEvent) {
    session = (event, Date().addingTimeInterval(sessionLength))
    startTimer()
    tick()
  }

  /// 幂等。
  func cancel() {
    panel.hide()
    session = nil
    stopTimer()
  }

  /// 用户点了卡片：把焦点设回目标元素，再逐字键入。
  func fill() {
    guard let session else {
      return
    }
    // 面板可能已经在那儿挂了一会儿，键入前重新确认目标；探不到就什么都不做，
    // 面板留着，让用户先点进输入框。
    guard let field = probe(ownPID, primaryScreenHeight) else {
      return
    }
    _ = AXUIElementSetAttributeValue(field.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    panel.hide()
    self.session = nil
    stopTimer()
    sender.send(KeystrokeScript.make(text: session.event.code, pressReturn: pressesReturn))
  }

  // MARK: - 轮询

  private func startTimer() {
    guard timer == nil else {
      return
    }
    let timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.tick()
      }
    }
    timer.tolerance = 0.05
    self.timer = timer
  }

  private func stopTimer() {
    timer?.invalidate()
    timer = nil
    isProbing = false
  }

  private func tick() {
    guard let session else {
      return
    }
    if Date() >= session.deadline {
      cancel()
      return
    }
    guard !isProbing else {
      return
    }
    isProbing = true
    let pid = ownPID
    let height = primaryScreenHeight
    let probe = self.probe
    queue.async { [weak self] in
      let field = probe(pid, height)
      DispatchQueue.main.async {
        MainActor.assumeIsolated {
          self?.apply(field)
        }
      }
    }
  }

  private func apply(_ field: FocusedField?) {
    isProbing = false
    guard let session else {
      return
    }
    if Date() >= session.deadline {
      cancel()
      return
    }
    // 焦点不在输入框上：面板收起来，会话继续——用户可能才刚要去点输入框。
    guard let field else {
      panel.hide()
      return
    }
    panel.show(
      event: session.event,
      pressesReturn: pressesReturn,
      anchor: field.frame,
      onFill: { [weak self] in self?.fill() },
      onDismiss: { [weak self] in self?.cancel() }
    )
  }
}
