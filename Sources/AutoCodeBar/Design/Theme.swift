import AppKit
import SwiftUI

/// 颜色、字体、间距、层次的唯一来源。
///
/// 每个界面都由这些令牌拼出来，而不是就地写死数值——这是设置窗口、引导流程和
/// 面板看起来像同一个产品而不是三个产品的原因。每个颜色都是动态 `NSColor`，
/// 浅色和深色是同一处声明，外观切换时视图不需要失效重建。
enum Theme {

  // MARK: - 表面

  /// 最底层；侧栏和内容卡片浮在它上面。
  static let window = Color.dynamic(light: 0xECECEE, dark: 0x0B0B0D)
  /// 页面背景——承载内容的大块白色平面。
  static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x151517)
  /// 卡片、凹槽和侧栏：比 `surface` 安静一档。
  static let sunken = Color.dynamic(light: 0xF6F6F8, dark: 0x1C1C1F)
  /// 行与导航项的悬停 / 按下底色。
  static let hover = Color.dynamic(light: 0xEDEDF0, dark: 0x232327)
  /// 选中的导航项。
  static let selected = Color.dynamic(light: 0xE4E4E8, dark: 0x2B2B30)
  /// 浮层：设置窗口、弹出面板。
  static let raised = Color.dynamic(light: 0xFFFFFF, dark: 0x1E1E22)

  // MARK: - 线

  static let stroke = Color.dynamic(light: 0xE6E6EA, dark: 0x2E2E34)
  static let strokeStrong = Color.dynamic(light: 0xD5D5DB, dark: 0x3C3C43)
  /// 卡片内部的分隔线——刻意比 `stroke` 更淡。
  static let hairline = Color.dynamic(light: 0xEFEFF2, dark: 0x27272C)
  /// 可编辑区域的边界：输入框、文本域。要在自己的填充色上过 3:1，
  /// 否则「这里能打字」这件事只能靠猜。
  static let inputStroke = Color.dynamic(light: 0x85858F, dark: 0x70707A)

  // MARK: - 墨

  static let ink = Color.dynamic(light: 0x0B0B0D, dark: 0xF4F4F6)
  /// 次级文字要在卡片底色上过 4.5:1，原来的灰在 `sunken` 上只有 3.4:1。
  static let inkSecondary = Color.dynamic(light: 0x6C6C76, dark: 0x9F9FA8)
  static let inkTertiary = Color.dynamic(light: 0xADADB4, dark: 0x6C6C74)
  /// `fill`（墨色药丸）之上的文字。
  static let onFill = Color.dynamic(light: 0xFFFFFF, dark: 0x0B0B0D)
  /// 高对比药丸：浅色下是黑，深色下是白。
  static let fill = Color.dynamic(light: 0x121214, dark: 0xF4F4F6)
  /// 开关打开的一侧：品牌青绿。
  ///
  /// 曾经是墨色，深色下就成了白轨道配黑旋钮，像反了色的开关。macOS 自己的开关
  /// 也是用强调色说「开」，这里跟着平台走，`accent` 因此多了这一个用途。
  static let controlOn = accent

  // MARK: - 语义

  /// 应用图标的青绿。只用于身份，绝不用于控件状态。
  static let accent = Color.dynamic(light: 0x0F9488, dark: 0x3FCFBF)
  static let accentSoft = Color.dynamic(light: 0xE6F5F3, dark: 0x12312D)
  static let positive = Color.dynamic(light: 0x1B9E5B, dark: 0x37C77E)
  static let positiveSoft = Color.dynamic(light: 0xE6F5EC, dark: 0x14301F)
  static let warning = Color.dynamic(light: 0xC77A08, dark: 0xE3A13A)
  static let warningSoft = Color.dynamic(light: 0xFCF2E2, dark: 0x33260F)
  static let danger = Color.dynamic(light: 0xD93A34, dark: 0xF2695F)
  static let dangerSoft = Color.dynamic(light: 0xFCECEB, dark: 0x361817)

  // MARK: - 度量

  /// 描边宽度。一根发丝线，和一圈明确到不会被误认成边框的焦点环。
  enum Stroke {
    static let hairline: CGFloat = 1
    static let focus: CGFloat = 2
  }

  enum Radius {
    static let small: CGFloat = 8
    static let control: CGFloat = 10
    static let card: CGFloat = 14
    static let panel: CGFloat = 18
    static let window: CGFloat = 12
  }

  enum Space {
    static let hairGap: CGFloat = 4
    static let tight: CGFloat = 8
    static let snug: CGFloat = 12
    static let regular: CGFloat = 16
    static let roomy: CGFloat = 24
    static let section: CGFloat = 36
    static let page: CGFloat = 32
  }

  // MARK: - 字体

  /// 每个界面开头的特大标题。
  static let display = Font.system(size: 38, weight: .bold)
  static let title = Font.system(size: 21, weight: .semibold)
  static let heading = Font.system(size: 15, weight: .semibold)
  static let body = Font.system(size: 13.5, weight: .regular)
  static let bodyStrong = Font.system(size: 13.5, weight: .medium)
  static let caption = Font.system(size: 12, weight: .regular)
  /// 分区标签——小、安静、字距略开。
  static let label = Font.system(size: 12.5, weight: .semibold)
  static let mono = Font.system(size: 12, weight: .regular, design: .monospaced)
  /// 一行里的第二行——Bundle ID 这类只在需要时才读的补充信息。
  static let micro = Font.system(size: 10.5, weight: .regular)

  // MARK: - 动效

  /// 一条曲线管所有状态切换：悬停、按下、开关。界面里的每次变化都用同一段
  /// 时间，用户才不用为每个控件重新建立一次预期。
  enum Motion {
    static let ui = Animation.easeOut(duration: 0.16)

    static var systemReducesMotion: Bool {
      NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// 「减弱动态效果」不等于「没有反馈」：变化仍要看得见，只是不再弹。
    static func reduced(_ animation: Animation, _ reduce: Bool = systemReducesMotion) -> Animation {
      reduce ? .easeOut(duration: 0.12) : animation
    }
  }
}

extension Color {
  /// 固定颜色——用于不该随外观漂移的品牌标记。
  static func hex(_ value: UInt32) -> Color {
    Color(nsColor: NSColor(rgbHex: value))
  }

  /// 按外观自解析的颜色，调用处不需要 `@Environment(\.colorScheme)` 布线。
  static func dynamic(light: UInt32, dark: UInt32) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
      return NSColor(rgbHex: isDark ? dark : light)
    })
  }
}

private extension NSColor {
  convenience init(rgbHex hex: UInt32) {
    self.init(
      srgbRed: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      alpha: 1
    )
  }
}

// MARK: - 层次

extension View {
  /// 卡片阴影：几乎看不见，但足以把白卡片从白底上抬起来。
  func cardShadow() -> some View {
    shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 3)
  }

  /// 浮层阴影：设置窗口等悬浮面板。
  func panelShadow() -> some View {
    shadow(color: .black.opacity(0.22), radius: 40, x: 0, y: 16)
  }
}
