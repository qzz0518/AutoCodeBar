import Combine
import Foundation
import Observation
import Sparkle

/// 齿轮菜单与设置页共用的 Sparkle 门面。
///
/// 直接跑 `swift build` 产出的可执行文件时没有组装好的 Info.plist，也就没有
/// 更新源地址；那种情况下启动 updater 只会弹出一个误导性的错误框。用
/// `SUFeedURL` 是否存在来判断当前是不是一个真正的应用包，不是就整体空转。
@MainActor
@Observable
final class AppUpdater {
  private(set) var canCheckForUpdates = false

  @ObservationIgnored private let controller: SPUStandardUpdaterController
  @ObservationIgnored private let isConfigured: Bool
  @ObservationIgnored private var canCheckObserver: AnyCancellable?

  init(bundle: Bundle = .main) {
    isConfigured = bundle.object(forInfoDictionaryKey: "SUFeedURL") != nil
    controller = SPUStandardUpdaterController(
      startingUpdater: isConfigured,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )

    guard isConfigured else {
      return
    }
    canCheckForUpdates = controller.updater.canCheckForUpdates
    canCheckObserver = controller.updater
      .publisher(for: \.canCheckForUpdates)
      .receive(on: RunLoop.main)
      .removeDuplicates()
      .sink { [weak self] canCheck in
        self?.canCheckForUpdates = canCheck
      }
  }

  /// 每日自动检查。未配置时读回 false、写入被忽略。
  var automaticallyChecksForUpdates: Bool {
    get {
      guard isConfigured else {
        return false
      }
      return controller.updater.automaticallyChecksForUpdates
    }
    set {
      guard isConfigured else {
        return
      }
      controller.updater.automaticallyChecksForUpdates = newValue
    }
  }

  func checkForUpdates() {
    guard isConfigured else {
      return
    }
    controller.checkForUpdates(nil)
  }
}
