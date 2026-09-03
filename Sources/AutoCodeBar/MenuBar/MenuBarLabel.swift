import SwiftUI

import AutoCodeBarCore

struct MenuBarLabel: View {
  let state: AppState

  private var isActive: Bool {
    if case .running(let sources) = state.overall {
      return !sources.isEmpty
    }
    return false
  }

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: isActive ? "key.horizontal.fill" : "key.horizontal")
      if let code = state.flashCode, state.settings.showCodeInMenuBar {
        Text(code)
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .transition(.opacity)
      }
    }
    .animation(.easeOut(duration: 0.25), value: state.flashCode)
  }
}
