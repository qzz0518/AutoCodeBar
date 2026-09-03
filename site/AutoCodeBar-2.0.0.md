<p align="center">
  <img src="https://raw.githubusercontent.com/qzz0518/AutoCodeBar/main/Resources/Screenshots/app-icon-rounded.png" width="96" alt="AutoCodeBar icon" />
</p>

<h2 align="center">AutoCodeBar</h2>
<p align="center">短信或邮件里的验证码，自动复制到剪贴板。</p>

## 更新日志

1. **2.0 全新重写**：应用启动即开始监听，不再需要先点开面板；暂停状态不会被面板刷新撕掉；三个来源各自独立启停、独立恢复。
2. **三个数据来源**：「信息」的短信与 iMessage、Apple Mail 的本地邮件，以及实验性的通知中心来源（默认关闭，可覆盖 iPhone 镜像等其他应用的通知）。
3. **打分式识别**：以关键词邻近度、字形、行位置和上下文打分挑出验证码，年份、金额、单号、尾号都会被排除；39 条真实语料作为回归测试，关键词与正则可在设置里改，并带实时测试框。
4. **菜单栏与通知**：识别到验证码即复制，菜单栏显示 15 秒，可选系统通知；面板保留最近 5 条，悬停即可再次复制。
5. **权限引导**：三步引导流程，「完整磁盘访问」提供一张会飞到系统设置窗口并跟随的引导卡片，把应用图标直接拖进权限列表即可。
6. **隐私**：历史只在内存中，最多 20 条，退出即清；验证码写入剪贴板时带机密标记；全程不联网，除更新检查外没有任何网络请求。
7. **安全分发**：Universal 2 应用与 DMG 均已完成 Developer ID 签名、Apple 公证和票据装订，并提供 Sparkle EdDSA 签名更新源。

## Changelog

1. **A complete 2.0 rewrite**: monitoring starts with the app instead of when the panel is first opened, a manual pause is no longer undone by the panel, and each source starts, fails and recovers on its own.
2. **Three sources**: SMS and iMessage from Messages, local mail from Apple Mail, and an experimental Notification Center source (off by default) that can also cover iPhone Mirroring and other apps.
3. **Scored extraction**: candidates are ranked by keyword proximity, shape, line position and surrounding context, so years, amounts, order numbers and card suffixes are rejected. 39 real-world samples guard the behaviour, and keywords and the pattern are editable with a live test field.
4. **Menu bar and notifications**: a recognised code is copied immediately, shown in the menu bar for 15 seconds, and optionally announced by a banner. The panel keeps the last five and re-copies on hover.
5. **Permission guidance**: a three-step setup flow, plus a Full Disk Access card that flies to the System Settings window, follows it, and hands you a draggable copy of the app icon for the permission list.
6. **Privacy**: history lives in memory only, capped at 20 entries and cleared on quit; codes are written to the pasteboard with the concealed-content marker; nothing is sent anywhere except the update check.
7. **Secure distribution**: the Universal 2 app and DMG are Developer ID-signed, Apple-notarized and stapled, with an EdDSA-signed Sparkle update feed.

## 安装 / Install

### Homebrew

```bash
brew install --cask qzz0518/tap/autocodebar
```

### DMG

下载下方的 `AutoCodeBar-2.0.0.dmg`，打开后将 AutoCodeBar 拖入 Applications。

Download `AutoCodeBar-2.0.0.dmg` below, open it, and drag AutoCodeBar into Applications.

首次运行请在「系统设置 › 隐私与安全性 › 完整磁盘访问」中启用 AutoCodeBar，
应用内的引导卡片会带你走完这一步。

On first launch, enable AutoCodeBar in System Settings › Privacy & Security › Full Disk Access.
The in-app guide card walks you through it.

## 兼容性 / Compatibility

- macOS 14 或更高版本 / macOS 14 or later
- Universal 2（Apple Silicon + Intel）
- 已在 macOS 15.7 实机验证 / Hardware-verified on macOS 15.7

> [!IMPORTANT]
> AutoCodeBar 只在本机读取「信息」与「邮件」的本地数据，且只读打开。
> AutoCodeBar reads the local Messages and Mail data on your own Mac, read-only, and nowhere else.
