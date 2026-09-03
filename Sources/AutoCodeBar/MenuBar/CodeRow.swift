import SwiftUI

import AutoCodeBarCore

struct CodeRow: View {
  let event: CodeEvent
  let tick: Date
  let onCopy: () -> Void
  let onRemove: () -> Void

  @State private var isHovering = false
  @State private var justCopied = false

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: event.kind.symbolName)
        .font(.system(size: 13))
        .foregroundStyle(.tertiary)
        .frame(width: 18)
        .padding(.top, 2)

      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(event.code)
            .font(.system(size: 17, weight: .semibold, design: .monospaced))
            .foregroundStyle(justCopied ? Color.accentColor : Color.primary)

          Spacer(minLength: 4)

          if justCopied {
            Text(L10n.text("已复制"))
              .font(.system(size: 11))
              .foregroundStyle(Color.accentColor)
          } else if isHovering {
            Button(L10n.text("复制"), action: copy)
              .controlSize(.mini)
          } else {
            Text(RelativeTime.string(for: event.receivedAt, now: tick))
              .font(.system(size: 11))
              .foregroundStyle(.tertiary)
          }
        }

        Text("\(event.senderDisplay) · \(event.preview)")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.tail)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(Color.primary.opacity(isHovering ? 0.06 : 0))
        .padding(.horizontal, 6)
    )
    .contentShape(Rectangle())
    .onHover { hovering in
      isHovering = hovering
    }
    .onTapGesture(perform: copy)
    .contextMenu {
      Button(L10n.text("复制"), action: copy)
      Button(L10n.text("从历史中移除"), action: onRemove)
    }
  }

  private func copy() {
    onCopy()
    withAnimation(.easeOut(duration: 0.2)) {
      justCopied = true
    }
    Task {
      try? await Task.sleep(nanoseconds: 1_200_000_000)
      withAnimation(.easeOut(duration: 0.2)) {
        justCopied = false
      }
    }
  }
}
