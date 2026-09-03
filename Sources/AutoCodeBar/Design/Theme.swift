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

  // MARK: - 墨

  static let ink = Color.dynamic(light: 0x0B0B0D, dark: 0xF4F4F6)
  static let inkSecondary = Color.dynamic(light: 0x8A8A90, dark: 0x93939B)
  static let inkTertiary = Color.dynamic(light: 0xADADB4, dark: 0x6C6C74)
  /// `fill`（墨色药丸）之上的文字。
  static let onFill = Color.dynamic(light: 0xFFFFFF, dark: 0x0B0B0D)
  /// 高对比药丸：浅色下是黑，深色下是白。
  static let fill = Color.dynamic(light: 0x121214, dark: 0xF4F4F6)
  /// 开关打开的一侧。
  ///
  /// 刻意用墨色而不是 `accent`：品牌色只负责身份，控件状态由这块墨色说话，
  /// 一个颜色不该同时承担两件不相干的事。
  static let controlOn = fill

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
