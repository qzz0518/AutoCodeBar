import AppKit
import SwiftUI
import UniformTypeIdentifiers

import AutoCodeBarCore

/// 通知忽略列表：按应用挑，不再让用户手抄 Bundle ID。
struct IgnoredAppsList: View {
  let state: AppState

  private var apps: [String] {
    state.settings.ignoredNotificationApps
  }

  /// 空态是一句话，装不下也不需要滚动；有内容时到 200pt 封顶后开始滚。
  private var listHeight: CGFloat {
    apps.isEmpty ? 56 : min(CGFloat(apps.count) * IgnoredAppRow.height, 200)
  }

  var body: some View {
    Panel {
      VStack(alignment: .leading, spacing: 10) {
        Text(L10n.text("忽略这些应用的通知"))
          .font(Theme.heading)
          .foregroundStyle(Theme.ink)

        list

        HStack(spacing: Theme.Space.snug) {
          AddIgnoredAppButton(state: state)
          Spacer(minLength: Theme.Space.tight)
          Button(L10n.text("恢复默认")) {
            state.restoreDefaultIgnoredApps()
          }
          .buttonStyle(.plain)
          .font(.system(size: 11))
          .foregroundStyle(Theme.inkSecondary)
        }

        Text(L10n.text("默认忽略 Telegram，避免聊天内容误触发。AutoCodeBar 自身的通知始终忽略。"))
          .font(Theme.caption)
          .foregroundStyle(Theme.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var list: some View {
    ScrollView {
      if apps.isEmpty {
        Text(L10n.text("不忽略任何应用"))
          .font(Theme.caption)
          .foregroundStyle(Theme.inkTertiary)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
      } else {
        LazyVStack(spacing: 0) {
          ForEach(apps, id: \.self) { bundleIdentifier in
            IgnoredAppRow(bundleIdentifier: bundleIdentifier) {
              state.removeIgnoredApp(bundleIdentifier)
            }
          }
        }
      }
    }
    .scrollBounceBehavior(.basedOnSize)
    .frame(height: listHeight)
    .background(
      Theme.surface,
      in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        .strokeBorder(Theme.stroke, lineWidth: 1)
    )
  }
}

private struct IgnoredAppRow: View {
  static let height: CGFloat = 36

  let bundleIdentifier: String
  let remove: () -> Void

  @State private var hovering = false

  var body: some View {
    let info = IgnoredAppInfo.lookup(bundleIdentifier)

    HStack(spacing: Theme.Space.tight) {
      Image(nsImage: info.icon)
        .resizable()
        .interpolation(.high)
        .frame(width: 20, height: 20)

      if let name = info.name {
        Text(name)
          .font(Theme.body)
          .foregroundStyle(Theme.ink)
          .lineLimit(1)
        Spacer(minLength: Theme.Space.tight)
        Text(bundleIdentifier)
          .font(Theme.caption)
          .foregroundStyle(Theme.inkTertiary)
          .lineLimit(1)
          .truncationMode(.middle)
      } else {
        // 装不到应用就没有名字可显示，Bundle ID 顶上来当标题，用等宽字体
        // 说明这是一串标识符而不是应用名。
        Text(bundleIdentifier)
          .font(Theme.mono)
          .foregroundStyle(Theme.ink)
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer(minLength: Theme.Space.tight)
      }

      Button(action: remove) {
        Image(systemName: "xmark.circle.fill")
      }
      .buttonStyle(IconButtonStyle(size: 24))
      .help(L10n.text("移除"))
      .opacity(hovering ? 1 : 0.55)
    }
    .padding(.horizontal, 10)
    .frame(height: Self.height)
    .background(
      RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
        .fill(hovering ? Theme.hover : Color.clear)
    )
    .onHover { hovering = $0 }
  }
}

/// 加号菜单：运行中的应用直接挑，其余的从访达里选。
private struct AddIgnoredAppButton: View {
  let state: AppState

  @State private var running: [RunningApp] = []

  var body: some View {
    Menu {
      Menu(L10n.text("运行中的应用程序")) {
        ForEach(running) { app in
          Button {
            state.addIgnoredApps([app.id])
          } label: {
            Label {
              Text(app.name)
            } icon: {
              Image(nsImage: app.icon)
            }
          }
          .disabled(state.settings.ignoredNotificationApps.contains(app.id))
        }
      }
      Divider()
      Button(L10n.text("手动从访达中选择…")) {
        chooseFromFinder()
      }
    } label: {
      Label(L10n.text("添加应用"), systemImage: "plus")
    }
    // 面板本身就是 `Theme.sunken`，按钮再用同一块底色就消失了；换成
    // 列表那层 `Theme.surface`，两者在深浅两套外观下都还分得开。
    .menuStyle(.button)
    .buttonStyle(SoftButtonStyle(tone: Theme.surface))
    .menuIndicator(.hidden)
    .fixedSize()
    // 菜单没有「即将打开」的回调，但指针一定先经过按钮：进入时重扫一遍，
    // 弹出来的子菜单就是当下真正在运行的那些应用。
    .onHover { inside in
      if inside {
        running = RunningApp.current(excluding: state.ownBundleIdentifier)
      }
    }
    .onAppear {
      running = RunningApp.current(excluding: state.ownBundleIdentifier)
    }
  }

  private func chooseFromFinder() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.applicationBundle]
    panel.allowsMultipleSelection = true
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    // 应用是包，不关掉这个开关就会一路走进 Contents/ 而选不到 .app 本身。
    panel.treatsFilePackagesAsDirectories = false
    panel.directoryURL = FileManager.default
      .urls(for: .applicationDirectory, in: .localDomainMask)
      .first
    guard panel.runModal() == .OK else {
      return
    }
    state.addIgnoredApps(IgnoredAppInfo.bundleIdentifiers(at: panel.urls))
  }
}

/// 菜单里的一项：一个正在运行、且在程序坞里露面的应用。
struct RunningApp: Identifiable {
  /// 小写 Bundle ID，同时充当去重的键。
  let id: String
  let name: String
  let icon: NSImage

  @MainActor
  static func current(excluding own: String) -> [RunningApp] {
    var seen = Set<String>()
    var result: [RunningApp] = []
    for application in NSWorkspace.shared.runningApplications {
      // `.regular` 之外是后台代理和菜单栏小工具，它们不发通知给用户看，
      // 列出来只会把菜单撑成一屏进程表。
      guard application.activationPolicy == .regular,
            let identifier = application.bundleIdentifier?.lowercased(),
            identifier != own,
            seen.insert(identifier).inserted else {
        continue
      }
      result.append(
        RunningApp(
          id: identifier,
          name: application.localizedName ?? identifier,
          icon: menuIcon(for: application)
        )
      )
    }
    return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  /// 改的是副本：`NSRunningApplication.icon` 是共享实例，就地设尺寸会波及
  /// 其他画到这张图的地方。
  @MainActor
  private static func menuIcon(for application: NSRunningApplication) -> NSImage {
    let source = application.icon ?? NSWorkspace.shared.icon(for: .applicationBundle)
    guard let copy = source.copy() as? NSImage else {
      return source
    }
    copy.size = NSSize(width: 16, height: 16)
    return copy
  }
}
