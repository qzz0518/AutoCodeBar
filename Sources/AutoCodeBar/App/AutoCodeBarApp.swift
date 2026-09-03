import SwiftUI

@main
struct AutoCodeBarApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

  var body: some Scene {
    MenuBarExtra {
      PopoverView(state: delegate.state)
    } label: {
      MenuBarLabel(state: delegate.state)
    }
    .menuBarExtraStyle(.window)
  }
}
