import SwiftUI

import AutoCodeBarCore

struct PopoverView: View {
  let state: AppState

  @State private var tick = Date()

  private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

  private var needsAttention: Bool {
    switch state.overall {
    case .needsFullDiskAccess, .failed, .noSources: return true
    case .running, .paused: return false
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      PopoverHeader(state: state, openSettings: openSettings)

      Divider()

      if needsAttention {
        AttentionCard(state: state, openSettings: openSettings)
      }

      HStack {
        Text(L10n.text("最近验证码"))
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
        Spacer()
        if !state.history.isEmpty {
          Button(L10n.text("清空")) { state.clearHistory() }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 12)
      .padding(.top, 10)
      .padding(.bottom, 4)

      if state.history.isEmpty {
        EmptyStateView()
      } else {
        VStack(spacing: 0) {
          ForEach(state.history.prefix(5)) { event in
            CodeRow(
              event: event,
              tick: tick,
              onCopy: { state.copyAgain(event) },
              onRemove: { state.remove(event) }
            )
          }
        }
      }
    }
    .padding(.bottom, 8)
    .frame(width: 320)
    .onAppear {
      state.refreshPermissions()
      tick = Date()
    }
    .onReceive(timer) { value in
      tick = value
    }
  }

  private func openSettings() {
    state.openSettingsWindow()
  }
}
