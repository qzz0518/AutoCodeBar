import SwiftUI

import AutoCodeBarCore

/// 贴在聚焦输入框旁边的小卡片：一句「填入 482913」，点一下就键入。
///
/// 刻意不放任何说明文字——面板就贴在目标输入框下面，位置本身说明了它要做什么。
struct QuickFillCard: View {
  let event: CodeEvent
  let onFill: () -> Void
  let onDismiss: () -> Void

  @State private var hovering = false

  var body: some View {
    HStack(spacing: 10) {
      Button(action: onFill) {
        HStack(spacing: 10) {
          icon
          VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
              Text(L10n.text("填入"))
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.ink)
              Text(verbatim: event.code)
                .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink)
            }
            Text(L10n.format("来自 %@ · %@", event.senderDisplay, event.kind.shortName))
              .font(Theme.caption)
              .foregroundStyle(Theme.inkSecondary)
              .lineLimit(1)
          }
          Spacer(minLength: 6)
        }
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(hovering ? Theme.hover : Color.clear)
        )
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Button(action: onDismiss) {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(Theme.inkTertiary)
      }
      .buttonStyle(IconButtonStyle(size: 20))
      .help(L10n.text("关闭"))
      .opacity(hovering ? 1 : 0.55)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(minWidth: 200, maxWidth: 340)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Theme.raised)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(Theme.stroke, lineWidth: Theme.Stroke.hairline)
    )
    // 阴影由 NSPanel 自己画（`hasShadow = true`）：窗口阴影按内容的透明形状生成，
    // 不会像自绘阴影那样被无边框面板的边界裁成一个硬边灰框。
    .onHover { hovering = $0 }
    .animation(.easeOut(duration: 0.12), value: hovering)
    .fixedSize()
  }

  private var icon: some View {
    ZStack {
      Circle().fill(Theme.accentSoft)
      Image(systemName: event.kind.symbolName)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Theme.accent)
    }
    .frame(width: 26, height: 26)
  }
}
