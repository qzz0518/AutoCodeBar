import AppKit
import Foundation
import Observation
import UserNotifications

import AutoCodeBarCore

/// 面板头部展示用的总体状态。
enum OverallStatus: Equatable {
  struct Failure: Equatable {
    let kind: SourceKind
    let reason: String
  }

  case running([SourceKind])
  case paused
  case needsFullDiskAccess
  case failed([Failure])
  case noSources
}

@MainActor
@Observable
final class AppState {
  // MARK: - 对外状态

  private(set) var sourceStatuses: [SourceKind: SourceStatus] = [:]
  private(set) var history: [CodeEvent] = []
  private(set) var isPaused = false
  private(set) var flashCode: String?
  private(set) var fullDiskAccess: PermissionProbe.FDAState
  private(set) var notificationAuth: UNAuthorizationStatus = .notDetermined
  /// 规则页正则编译错误；非 nil 时沿用上一次有效规则。
  private(set) var rulesError: String?
  private(set) var launchAtLoginError: String?
  /// 用户点过「打开完整磁盘访问设置」且 10 秒后仍未生效时为真。
  private(set) var showRelaunchHint = false

  var settings: AppSettings {
    didSet {
      guard settings != oldValue else {
        return
      }
      AppSettingsStore.save(settings, to: defaults)
      applySettingsDiff(old: oldValue, new: settings)
    }
  }

  // MARK: - 依赖

  /// Sparkle 门面，由 AppDelegate 创建并持有。
  let updater: AppUpdater

  private let defaults: UserDefaults
  private let pipeline: CodePipeline
  private let clipboard: Clipboard
  private let presenter = NotificationPresenter()
  private let onboardingController = OnboardingWindowController()

  private var monitors: [SourceKind: SourceMonitor] = [:]
  private var tasks: [SourceKind: Task<Void, Never>] = [:]
  private var flashTask: Task<Void, Never>?
  private var relaunchHintTask: Task<Void, Never>?
  private var permissionTimer: Timer?
  private var permissionTick = 0
  private var didBootstrap = false

  init(updater: AppUpdater, defaults: UserDefaults = .standard) {
    self.updater = updater
    self.defaults = defaults
    // 探测只是两次 `open()`，同步做掉，界面第一帧就是真实状态，
    // 不会先闪一下「未授权」。
    self.fullDiskAccess = PermissionProbe.fullDiskAccess()
    let loaded = AppSettingsStore.load(from: defaults)
    self.settings = loaded
    let clipboard = PasteboardClipboard()
    self.clipboard = clipboard
    let rules = (try? ExtractionRules.make(from: loaded)) ?? .defaults
    self.pipeline = CodePipeline(
      extractor: CodeExtractor(rules: rules),
      clipboard: clipboard,
      ignoredNotificationApps: loaded.ignoredNotificationApps
    )
    for kind in SourceKind.allCases {
      sourceStatuses[kind] = .off
    }
    pipeline.onEvent = { [weak self] event, copied in
      self?.handle(event: event, copied: copied)
    }
    presenter.onOpenCode = { [weak self] code in
      _ = self?.clipboard.copy(code)
    }
  }

  // MARK: - 生命周期

  func bootstrap() {
    guard !didBootstrap else {
      return
    }
    didBootstrap = true

    presenter.configure()
    SettingsWindowController.shared.configure(state: self)
    refreshPermissions()
    startEnabledSources()

    NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.refreshPermissions()
      }
    }

    // 每 2 秒触发一次：欢迎窗可见时每次都探测，否则仅在有源等待授权时每 10 秒探测一次。
    let timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else {
          return
        }
        self.permissionTick &+= 1
        if self.onboardingController.isVisible {
          self.refreshPermissions()
        } else if self.sourceStatuses.values.contains(.needsFullDiskAccess), self.permissionTick % 5 == 0 {
          self.refreshPermissions()
        }
      }
    }
    permissionTimer = timer

    if !settings.onboardingCompleted {
      showOnboarding()
    }
  }

  func showOnboarding() {
    onboardingController.show(state: self)
  }

  /// 引导完成：写标记、清进度键、关窗。
  func finishOnboarding() {
    settings.onboardingCompleted = true
    UserDefaults.standard.removeObject(forKey: OnboardingFlow.Step.progressKey)
    onboardingController.close()
  }

  /// 打开设置窗口。
  func openSettingsWindow() {
    SettingsWindowController.shared.show()
  }

  /// 设置 › 通用 里的「重新运行设置向导」。
  func restartOnboarding() {
    settings.onboardingCompleted = false
    UserDefaults.standard.removeObject(forKey: OnboardingFlow.Step.progressKey)
    showOnboarding()
  }

  // MARK: - 监听控制

  func pause() {
    guard !isPaused else {
      return
    }
    isPaused = true
    for kind in SourceKind.allCases {
      stopSource(kind)
    }
  }

  func resume() {
    guard isPaused else {
      return
    }
    isPaused = false
    startEnabledSources()
  }

  func setSource(_ kind: SourceKind, enabled: Bool) {
    settings.sources[kind] = enabled
  }

  func retryFailedSources() {
    for kind in settings.enabledSources where sourceStatuses[kind]?.isBlocking == true {
      startSource(kind)
    }
  }

  private func startEnabledSources() {
    guard !isPaused else {
      return
    }
    for kind in settings.enabledSources {
      startSource(kind)
    }
  }

  private func startSource(_ kind: SourceKind) {
    stopSource(kind)
    guard settings.isEnabled(kind), !isPaused else {
      return
    }
    let monitor = makeMonitor(kind)
    monitors[kind] = monitor
    sourceStatuses[kind] = .starting
    let stream = monitor.start()
    tasks[kind] = Task { [weak self, weak monitor] in
      for await event in stream {
        guard let self, let monitor, self.monitors[kind] === monitor else {
          return
        }
        switch event {
        case .status(let status):
          self.sourceStatuses[kind] = status
        case .candidate(let candidate):
          self.pipeline.handle(candidate)
        }
      }
    }
  }

  private func stopSource(_ kind: SourceKind) {
    monitors[kind]?.stop()
    monitors[kind] = nil
    tasks[kind]?.cancel()
    tasks[kind] = nil
    sourceStatuses[kind] = .off
  }

  private func makeMonitor(_ kind: SourceKind) -> SourceMonitor {
    switch kind {
    case .messages: return MessagesMonitor()
    case .mail: return MailMonitor()
    case .notificationCenter: return NotificationCenterMonitor()
    }
  }

  // MARK: - 设置变更

  private func applySettingsDiff(old: AppSettings, new: AppSettings) {
    for kind in SourceKind.allCases where old.isEnabled(kind) != new.isEnabled(kind) {
      if new.isEnabled(kind) {
        startSource(kind)
      } else {
        stopSource(kind)
      }
    }

    if old.keywords != new.keywords || old.codePattern != new.codePattern {
      rebuildRules()
    }

    if old.ignoredNotificationApps != new.ignoredNotificationApps {
      pipeline.updateIgnoredNotificationApps(new.ignoredNotificationApps)
    }
  }

  private func rebuildRules() {
    do {
      let rules = try ExtractionRules.make(from: settings)
      pipeline.extractor = CodeExtractor(rules: rules)
      rulesError = nil
    } catch {
      rulesError = error.localizedDescription
    }
  }

  func restoreDefaultRules() {
    settings.keywords = AppSettings.defaultKeywords
    settings.codePattern = AppSettings.defaultCodePattern
  }

  // MARK: - 权限

  func refreshPermissions() {
    Task.detached(priority: .utility) { [weak self] in
      let probed = PermissionProbe.fullDiskAccess()
      await self?.applyFullDiskAccess(probed)
    }
    Task { [weak self] in
      let status = await PermissionProbe.notificationAuthorization()
      self?.notificationAuth = status
    }
  }

  /// 打开系统设置的完整磁盘访问面板并弹出拖拽引导卡片；
  /// 10 秒后若仍未生效则显示「重新启动应用」。
  func openFullDiskAccessSettings() {
    FullDiskAccessGuide.shared.present()
    relaunchHintTask?.cancel()
    relaunchHintTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 10 * NSEC_PER_SEC)
      guard !Task.isCancelled, let self, self.fullDiskAccess != .granted else {
        return
      }
      self.showRelaunchHint = true
    }
  }

  private func applyFullDiskAccess(_ state: PermissionProbe.FDAState) {
    fullDiskAccess = state
    if state == .granted {
      relaunchHintTask?.cancel()
      relaunchHintTask = nil
      showRelaunchHint = false
    }
    guard state == .granted, !isPaused else {
      return
    }
    for kind in settings.enabledSources where sourceStatuses[kind] == .needsFullDiskAccess {
      startSource(kind)
    }
  }

  func requestNotificationAuthorization() {
    Task { [weak self] in
      guard let self else {
        return
      }
      _ = await self.presenter.requestAuthorization()
      self.notificationAuth = await PermissionProbe.notificationAuthorization()
    }
  }

  // MARK: - 事件

  private func handle(event: CodeEvent, copied: Bool) {
    history = pipeline.history.events
    if settings.showCodeInMenuBar {
      flash(event.code)
    }
    if copied, settings.showCopyNotification {
      presenter.present(event)
    }
  }

  private func flash(_ code: String) {
    flashTask?.cancel()
    flashCode = code
    flashTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 15 * NSEC_PER_SEC)
      guard !Task.isCancelled else {
        return
      }
      self?.flashCode = nil
    }
  }

  @discardableResult
  func copyAgain(_ event: CodeEvent) -> Bool {
    clipboard.copy(event.code)
  }

  func remove(_ event: CodeEvent) {
    pipeline.remove(event)
    history = pipeline.history.events
  }

  func clearHistory() {
    pipeline.clearHistory()
    history = pipeline.history.events
  }

  /// 规则页的无副作用测试。
  func testExtraction(_ text: String) -> Extraction? {
    pipeline.extractor.extract(text: text, context: .message)
  }

  // MARK: - 登录时启动

  var launchAtLogin: Bool {
    LaunchAtLogin.isEnabled
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    do {
      try LaunchAtLogin.set(enabled)
      launchAtLoginError = nil
    } catch {
      launchAtLoginError = error.localizedDescription
    }
  }

  // MARK: - 推导状态

  var overall: OverallStatus {
    if isPaused {
      return .paused
    }
    let enabled = settings.enabledSources
    if enabled.contains(where: { sourceStatuses[$0] == .needsFullDiskAccess }) {
      return .needsFullDiskAccess
    }
    if enabled.isEmpty {
      return .noSources
    }
    let running = enabled.filter { sourceStatuses[$0]?.isRunning == true }
    if running.isEmpty {
      let failures: [OverallStatus.Failure] = enabled.compactMap { kind in
        switch sourceStatuses[kind] {
        case .failed(let message), .unavailable(let message):
          return OverallStatus.Failure(kind: kind, reason: message)
        default:
          return nil
        }
      }
      if failures.count == enabled.count {
        return .failed(failures)
      }
      return .running([])
    }
    return .running(running)
  }
}

#if DEBUG
extension AppState {
  /// 仅供 `DebugSnapshot` 使用：不启动任何监听器，直接摆出一组用于截图的示例状态。
  func debugInstallSampleState() {
    isPaused = false
    fullDiskAccess = .granted
    sourceStatuses = [.messages: .running, .mail: .running, .notificationCenter: .off]
    let now = Date()
    history = [
      CodeEvent(
        code: "482913",
        kind: .messages,
        senderDisplay: "京东",
        preview: "【京东】验证码 482913，5 分钟内有效。如非本人操作请忽略。",
        receivedAt: now.addingTimeInterval(-20)
      ),
      CodeEvent(
        code: "RKJ-YP6",
        kind: .mail,
        senderDisplay: "GitHub",
        preview: "Your GitHub launch code Continue signing up for GitHub by entering the code below",
        receivedAt: now.addingTimeInterval(-3 * 60)
      ),
      CodeEvent(
        code: "664120",
        kind: .mail,
        senderDisplay: "Apple",
        preview: "Verify your email address Enter the following number in the app to continue",
        receivedAt: now.addingTimeInterval(-42 * 60)
      )
    ]
  }
}
#endif
