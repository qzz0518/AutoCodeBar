#if DEBUG
import AppKit
import SwiftUI

import AutoCodeBarCore

/// 开发用：
/// - `AutoCodeBar --snapshot-popover <png 路径> [--snapshot-appearance dark|light]`
///   用一组示例数据把面板渲染成 PNG 后立即退出，README 截图靠它生成。
///   菜单栏图标可能被 Ice / Bartender 这类管理器藏到屏外，靴子式点开再截图并不可靠。
/// - `AutoCodeBar --snapshot-window <名称> <png 路径> [--snapshot-appearance dark|light]`
///   把设置窗、引导窗或授权卡片离屏画成 PNG。名称见 `Window`。
///   这条路径不需要屏幕解锁，也不需要窗口真的出现在屏幕上。
@MainActor
enum DebugSnapshot {
  /// 快照进行中。`ImageRenderer` 画不出 `Menu`，视图据此改用静态占位。
  static var isActive = false

  /// 可离屏渲染的界面，以及它们各自的固定尺寸。
  enum Window: String, CaseIterable {
    case settingsGeneral = "settings-general"
    case settingsSources = "settings-sources"
    case settingsRules = "settings-rules"
    case settingsPermissions = "settings-permissions"
    case settingsAbout = "settings-about"
    case onboardingWelcome = "onboarding-welcome"
    case onboardingPermissions = "onboarding-permissions"
    case onboardingDone = "onboarding-done"
    case guideCard = "guide-card"
    case guideCardGranted = "guide-card-granted"
    case popover = "popover"

    var size: NSSize {
      switch self {
      case .settingsGeneral, .settingsSources, .settingsRules,
           .settingsPermissions, .settingsAbout:
        return NSSize(width: 800, height: 580)
      case .onboardingWelcome, .onboardingPermissions, .onboardingDone:
        return NSSize(width: 920, height: 600)
      case .guideCard, .guideCardGranted:
        return NSSize(width: 612, height: 140)
      case .popover:
        // 高度随历史条数变化，0 表示按内容自适应。
        return NSSize(width: 320, height: 0)
      }
    }

    var settingsTab: SettingsTab? {
      switch self {
      case .settingsGeneral: return .general
      case .settingsSources: return .sources
      case .settingsRules: return .rules
      case .settingsPermissions: return .permissions
      case .settingsAbout: return .about
      default: return nil
      }
    }

    var onboardingStep: OnboardingFlow.Step? {
      switch self {
      case .onboardingWelcome: return .welcome
      case .onboardingPermissions: return .permissions
      case .onboardingDone: return .done
      default: return nil
      }
    }
  }

  /// 命中参数时接管启动流程并返回 true；调用方此时不应再 `bootstrap()`。
  static func runIfRequested(state: AppState) -> Bool {
    let arguments = CommandLine.arguments
    if let index = arguments.firstIndex(of: "--snapshot-popover"), index + 1 < arguments.count {
      isActive = true
      applyAppearance(arguments)
      state.debugInstallSampleState()
      renderPopover(state: state, to: URL(fileURLWithPath: arguments[index + 1]))
    }
    if let index = arguments.firstIndex(of: "--snapshot-window"), index + 2 < arguments.count {
      guard let window = Window(rawValue: arguments[index + 1]) else {
        let names = Window.allCases.map(\.rawValue).joined(separator: ", ")
        FileHandle.standardError.write(Data("snapshot: unknown window; expected one of \(names)\n".utf8))
        exit(2)
      }
      isActive = true
      applyAppearance(arguments)
      state.debugInstallSampleState()
      renderWindow(window, state: state, to: URL(fileURLWithPath: arguments[index + 2]))
    }
    return false
  }

  private static func applyAppearance(_ arguments: [String]) {
    let dark: Bool
    if let index = arguments.firstIndex(of: "--snapshot-appearance"), index + 1 < arguments.count {
      dark = arguments[index + 1] != "light"
    } else {
      dark = true
    }
    NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
  }

  private static var prefersDark: Bool {
    NSApp.appearance?.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
  }

  private static func renderPopover(state: AppState, to output: URL) -> Never {
    let view = PopoverView(state: state)
      .frame(width: 320)
      .background(Color(nsColor: .windowBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      .environment(\.colorScheme, prefersDark ? .dark : .light)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    renderer.isOpaque = false

    guard let image = renderer.cgImage else {
      FileHandle.standardError.write(Data("snapshot: render failed\n".utf8))
      exit(2)
    }
    write(NSBitmapImageRep(cgImage: image), to: output)
  }

  /// 走 AppKit 的离屏绘制，而不是 `ImageRenderer`：设置页里有文本框和开关这类
  /// 由 AppKit 视图撑起来的控件，`ImageRenderer` 会把它们画成空白。
  private static func renderWindow(_ window: Window, state: AppState, to output: URL) -> Never {
    if let step = window.onboardingStep {
      UserDefaults.standard.set(step.rawValue, forKey: OnboardingFlow.Step.progressKey)
    }

    let hosting = NSHostingView(rootView: content(for: window, state: state))
    var size = window.size
    if size.height == 0 {
      hosting.frame = NSRect(x: 0, y: 0, width: size.width, height: 1)
      size.height = hosting.fittingSize.height
    }
    hosting.frame = NSRect(origin: .zero, size: size)

    // 无边框离屏面板：宿主视图必须挂在一个有 backing store 的窗口里才能取到
    // Retina 比例，SwiftUI 也才会真正跑一遍布局。
    let panel = NSPanel(
      contentRect: hosting.frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    panel.contentView = hosting
    panel.appearance = NSApp.appearance
    panel.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
    panel.orderBack(nil)

    // SwiftUI 的第一遍布局是异步的；跑几轮 runloop 让它落定再取图。
    for _ in 0..<12 {
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
      hosting.layoutSubtreeIfNeeded()
      hosting.displayIfNeeded()
    }

    guard let representation = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
      FileHandle.standardError.write(Data("snapshot: cannot allocate bitmap\n".utf8))
      exit(2)
    }
    hosting.cacheDisplay(in: hosting.bounds, to: representation)
    write(representation, to: output)
  }

  @ViewBuilder
  private static func content(for window: Window, state: AppState) -> some View {
    if let tab = window.settingsTab {
      SettingsView(state: state, initialTab: tab)
    } else if window.onboardingStep != nil {
      OnboardingFlow(state: state)
    } else if window == .popover {
      PopoverView(state: state)
        .background(Color(nsColor: .windowBackgroundColor))
    } else {
      FullDiskAccessGuide.debugCard(granted: window == .guideCardGranted)
        .frame(width: window.size.width, height: window.size.height)
    }
  }

  private static func write(_ representation: NSBitmapImageRep, to output: URL) -> Never {
    guard let data = representation.representation(using: .png, properties: [:]) else {
      FileHandle.standardError.write(Data("snapshot: png encode failed\n".utf8))
      exit(3)
    }
    do {
      try data.write(to: output)
      print("snapshot: wrote \(output.path) (\(representation.pixelsWide)x\(representation.pixelsHigh))")
      exit(0)
    } catch {
      FileHandle.standardError.write(Data("snapshot: \(error.localizedDescription)\n".utf8))
      exit(4)
    }
  }
}
#endif
