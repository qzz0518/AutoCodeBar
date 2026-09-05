import AppKit
import SwiftUI
import UniformTypeIdentifiers

import AutoCodeBarCore

/// 通知忽略列表：按应用挑，不再让用户手抄 Bundle ID。
struct IgnoredAppsList: View {
  let state: AppState

  /// 一屏最多露六行，再多就滚——这块列表只是设置页里的一段，不是主角。
  private static let visibleRows = 6

  private var apps: [String] {
    state.settings.ignoredNotificationApps
  }

  /// 「手动从访达中选择…」那一项的 ID。不是合法的 Bundle ID，不会和任何应用撞车。
  static let finderAction = "choose-from-finder"

  /// 空态是一句话，装不下也不需要滚动；48 加上容器四周各 4 的内缩正好 56。
  private var listHeight: CGFloat {
    apps.isEmpty
      ? 48
      : IgnoredAppRow.height * CGFloat(min(apps.count, Self.visibleRows))
  }

  var body: some View {
    Panel {
      VStack(alignment: .leading, spacing: 10) {
        Text(L10n.text("忽略这些应用的通知"))
          .font(Theme.heading)
          .foregroundStyle(Theme.ink)

        well

        HStack(alignment: .center, spacing: Theme.Space.snug) {
          AddIgnoredAppButton(state: state)
          Spacer(minLength: Theme.Space.tight)
          Button(L10n.text("恢复默认")) {
            state.restoreDefaultIgnoredApps()
          }
          .buttonStyle(.plain)
          .font(Theme.caption)
          .foregroundStyle(Theme.inkSecondary)
        }

        Text(L10n.text("默认忽略 Telegram，避免聊天内容误触发。AutoCodeBar 自身的通知始终忽略。"))
          .font(Theme.caption)
          .foregroundStyle(Theme.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  /// 行有自己的圆角，容器就得比它更圆一档：8 的行缩进 4，外圈 12 才是同心的。
  private var well: some View {
    Group {
      if apps.isEmpty {
        Text(L10n.text("不忽略任何应用"))
          .font(Theme.caption)
          .foregroundStyle(Theme.inkTertiary)
          .frame(maxWidth: .infinity)
          .frame(height: listHeight)
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(apps, id: \.self) { bundleIdentifier in
              IgnoredAppRow(bundleIdentifier: bundleIdentifier) {
                state.removeIgnoredApp(bundleIdentifier)
              }
            }
          }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: listHeight)
      }
    }
    .padding(Theme.Space.hairGap)
    .background(
      Theme.surface,
      in: RoundedRectangle(cornerRadius: Theme.Radius.small + Theme.Space.hairGap, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: Theme.Radius.small + Theme.Space.hairGap, style: .continuous)
        .strokeBorder(Theme.stroke, lineWidth: Theme.Stroke.hairline)
    )
  }
}

private struct IgnoredAppRow: View {
  static let height: CGFloat = 38

  let bundleIdentifier: String
  let remove: () -> Void

  @State private var hovering = false

  var body: some View {
    let info = IgnoredAppInfo.lookup(bundleIdentifier)

    HStack(spacing: Theme.Space.tight) {
      Image(nsImage: info.icon)
        .resizable()
        .interpolation(.high)
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)

      if let name = info.name {
        VStack(alignment: .leading, spacing: 0) {
          Text(name)
            .font(Theme.body)
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
          Text(bundleIdentifier)
            .font(Theme.micro)
            .foregroundStyle(Theme.inkTertiary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      } else {
        // 装不到应用就没有名字可显示，Bundle ID 顶上来当标题，用等宽字体
        // 说明这是一串标识符而不是应用名。
        Text(bundleIdentifier)
          .font(Theme.mono)
          .foregroundStyle(Theme.ink)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Spacer(minLength: Theme.Space.tight)

      Button(action: remove) {
        Image(systemName: "xmark.circle.fill")
      }
      .buttonStyle(IconButtonStyle(size: 24, staticFeedback: true))
      .help(L10n.text("移除"))
      .accessibilityLabel(L10n.format("移除 %@", info.name ?? bundleIdentifier))
      .opacity(hovering ? 1 : 0.55)
    }
    .padding(.horizontal, 10)
    .frame(height: Self.height)
    .background(
      RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
        .fill(hovering ? Theme.hover : Color.clear)
    )
    .onHover { hovering = $0 }
    .accessibilityElement(children: .contain)
  }
}

/// 加号按钮：点开一张自绘的弹出列表，运行中的应用直接挑，其余的从访达里选。
private struct AddIgnoredAppButton: View {
  let state: AppState

  @State private var running: [RunningApp] = []
  @State private var expanded = false
  @State private var pendingFinder = false
  @FocusState private var focused: Bool

  var body: some View {
    Button {
      // 每次点开都重扫：列出来的必须是此刻真的在运行的那些应用。
      running = RunningApp.current(excluding: state.ownBundleIdentifier)
      expanded.toggle()
    } label: {
      Label(L10n.text("添加应用"), systemImage: "plus")
    }
    .buttonStyle(SettingsActionButtonStyle())
    .focused($focused)
    .focusEffectDisabled()
    .modifier(SettingsFocusRing(focused: focused))
    .popover(isPresented: $expanded, arrowEdge: .bottom) {
      SettingsChoiceList(
        title: L10n.text("运行中的应用程序"),
        selection: "",
        choices: running.map { SettingsChoice(id: $0.id, title: $0.name, image: $0.icon) },
        identifier: "ignored.add",
        // 列表项的 ID 一律小写；旧版本手输进来的条目可能还带大写，比对前先压平。
        disabledValues: Set(state.settings.ignoredNotificationApps.map { $0.lowercased() }),
        footer: SettingsChoice(
          id: IgnoredAppsList.finderAction,
          title: L10n.text("手动从访达中选择…"),
          symbol: "folder"
        )
      ) { id in
        if id == IgnoredAppsList.finderAction {
          pendingFinder = true
        } else {
          state.addIgnoredApps([id])
        }
        expanded = false
      } dismiss: {
        expanded = false
      }
      .frame(width: 320)
      // 访达面板要等这张 popover 真的收起来再开：popover 还在时跑模态循环会卡住。
      .onDisappear {
        guard pendingFinder else {
          return
        }
        pendingFinder = false
        chooseFromFinder()
      }
    }
    .onChange(of: expanded) { _, open in
      if !open {
        focused = true
      }
    }
    .accessibilityIdentifier("ignored.add")
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

/// 列表里的一项：一个正在运行、且在程序坞里露面的应用。
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
      // 列出来只会把列表撑成一屏进程表。
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
          icon: listIcon(for: application)
        )
      )
    }
    return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  /// 改的是副本：`NSRunningApplication.icon` 是共享实例，就地设尺寸会波及
  /// 其他画到这张图的地方。
  @MainActor
  private static func listIcon(for application: NSRunningApplication) -> NSImage {
    let source = application.icon ?? NSWorkspace.shared.icon(for: .applicationBundle)
    guard let copy = source.copy() as? NSImage else {
      return source
    }
    copy.size = NSSize(width: 16, height: 16)
    return copy
  }
}
