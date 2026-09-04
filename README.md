<div align="center">
  <img src="Resources/Screenshots/app-icon-rounded.png" width="128" alt="AutoCodeBar 图标" />
  <h1>AutoCodeBar</h1>
  <p><strong>短信和邮件里的验证码，自动复制到 Mac 的剪贴板。</strong></p>
  <p>原生、轻量、完全离线的 macOS 菜单栏工具。</p>
  <p>简体中文 · <a href="README_EN.md">English</a></p>
  <p>
    <a href="https://github.com/qzz0518/AutoCodeBar/stargazers"><img src="https://img.shields.io/github/stars/qzz0518/AutoCodeBar?style=flat-square" alt="GitHub Stars" /></a>
    <img src="https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple" alt="macOS 14+" />
    <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.0" />
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="MIT License" /></a>
    <a href="https://x.com/zerah_eth"><img src="https://img.shields.io/badge/follow-%40zerah__eth-111111?style=flat-square&logo=x&logoColor=white" alt="在 X 关注 @zerah_eth" /></a>
  </p>
</div>

<p align="center">
  <img src="Resources/Screenshots/overview.png" width="1100" alt="AutoCodeBar 总览：菜单栏面板、最近验证码与设置窗口" />
</p>

AutoCodeBar 常驻菜单栏，监听本机「信息」和「邮件」的新内容。识别出验证码后，它会立即复制到剪贴板、
在菜单栏显示这串数字约 15 秒，并可选地弹出一条系统通知。你只需要 ⌘V。识别全程在本机完成，
没有服务器、没有统计；唯一的网络访问是可关闭的更新检查。

> [!IMPORTANT]
> AutoCodeBar 读取的是「信息」与「邮件」保存在本机的数据文件，因此需要「完整磁盘访问」权限；
> 首次启动的引导会带你完成授权。它是独立项目，与 Apple 无关联、未获其背书。
> 「通知中心」来源属于实验功能，依赖 macOS 的私有数据库格式，系统升级后可能失效，默认关闭。

## 功能

- **三个来源，各自独立**：短信 / iMessage 读取「信息」的本地数据库；邮件监听 Apple Mail 新写入的
  `.emlx` 文件，支持纯文本、HTML、quoted-printable、base64 与多种字符集；通知中心（实验）读取系统通知
  数据库，可覆盖 iPhone 镜像等其他应用送达 Mac 的通知。每个来源可单独开关、显示自己的运行状态。
- **零延迟感知**：用 FSEvents 监听文件变化，不轮询。短信从到达到进入剪贴板通常在半秒内。
- **菜单栏闪码**：复制后菜单栏图标旁直接显示验证码，约 15 秒后自动隐藏；不想看通知也能确认复制成功。
- **系统通知**：可选。横幅显示「已复制验证码 482913 · 来自 京东 · 短信」。
- **一键填入**：验证码到达后 60 秒内，光标所在的输入框旁会浮出一张「填入 482913」的卡片，点一下就逐字键入，
  六格分框的验证码也适用。默认关闭，打开时需要辅助功能权限，授权引导与完整磁盘访问同款；剪贴板、菜单栏闪码与通知照常。
- **识别而不是匹配**：先用关键词门控（中、英、日、韩、繁体，可自定义），再对候选片段打分：与关键词的距离、
  是否位于关键词之后、位数、前后文（排除金额、单位、尾号、订单号、年份、URL 中的数字）。
  `G-482913`、`482-913`、`RKJ-YP6` 这类格式都能正确归一。39 条真实样式的语料作为回归测试。
- **跨来源去重**：同一条短信会同时出现在「信息」和通知中心，5 分钟内同一验证码只复制一次。
- **隐私内建**：历史只在内存中保留最多 20 条，退出即清；写入剪贴板时带 `org.nspasteboard.ConcealedType`
  标记，支持该约定的剪贴板管理器不会保存它。
- **权限引导**：完整磁盘访问不会弹出系统授权框。AutoCodeBar 会打开对应的系统设置页面，并在旁边浮出一张
  卡片——把卡片里的 AutoCodeBar 图标直接拖进权限列表即可，卡片会在授权生效后自动收起。
- **登录时启动**、**原生深浅色**、**规则实时测试**（粘贴一条短信立刻看到识别结果，不写剪贴板）。
- **安全更新**：通过 Sparkle 检查并安装 EdDSA 签名的新版本；安装包经 Developer ID 签名与 Apple 公证。
- **中英双语**：面板、设置、引导与通知跟随系统语言，可在「系统设置 › 语言与地区」为 AutoCodeBar 单独选择。

## 快速开始

### 系统要求

- macOS 14 或更高版本（实机验证：macOS 15.7）
- Apple Silicon 或 Intel Mac；通过 SwiftPM 在本机构建
- 短信来源需要在 iPhone 上开启「短信转发」到这台 Mac，或本机已登录 iMessage
- 邮件来源需要 Apple Mail 已配置账户并在本机同步邮件

### Homebrew

```bash
brew install --cask qzz0518/tap/autocodebar
```

Homebrew 6 起第三方 tap 需要信任：用上面的完整名称安装时只会信任这一个 cask；若想之后用短名 `autocodebar`，先执行 `brew tap qzz0518/tap` 与 `brew trust --cask qzz0518/tap/autocodebar`。

后续更新使用：

```bash
brew upgrade --cask autocodebar
```

### DMG 安装

前往 [Releases](https://github.com/qzz0518/AutoCodeBar/releases) 下载最新的 `AutoCodeBar-*.dmg`，
打开后将 AutoCodeBar 拖入 Applications。应用内的 Sparkle 会自动检查后续更新。

Homebrew 与 Releases 使用同一份经过 Developer ID 签名和 Apple 公证的 Universal 2 DMG。

### 从源码构建

需要 Xcode 26 或对应的 Command Line Tools（Swift 6.0+）：

```bash
git clone https://github.com/qzz0518/AutoCodeBar.git
cd AutoCodeBar
./script/build_and_run.sh
```

脚本会以 release 配置构建、组装 `dist/AutoCodeBar.app`、用本机可用的稳定签名身份签名并启动。
装了 [mise](https://mise.jdx.dev) 的话，`mise run verify` 会依次构建、测试、检查中英文资源与发布配置并组装 App。
安装到 Applications：

```bash
./script/build_and_run.sh --install
```

`/Applications` 不可写时会安装到 `~/Applications`。

> [!NOTE]
> 请通过 `.app` 运行，不要用 `swift run`：菜单栏应用需要完整的 bundle、`LSUIElement` 与稳定的代码签名，
> 否则「完整磁盘访问」授权无法关联到正确的主体。

### 关于签名

macOS 把「完整磁盘访问」授权绑定到应用的代码签名要求。ad-hoc 签名的要求是每次构建都会变化的 `cdhash`，
于是每次重新构建都要重新授权。构建脚本会按顺序选择 `CODESIGN_IDENTITY` 环境变量 →
钥匙串中的 `Developer ID Application` → `Apple Development` → ad-hoc，并在只能 ad-hoc 时打印警告。
有任意一张 Apple 开发证书就够了，不需要公证。

## 第一次使用

1. 启动后菜单栏出现钥匙图标，同时弹出引导窗口。若你使用 Ice、Bartender 一类的菜单栏管理器，新图标可能被直接收进隐藏区，请到管理器里把它拖出来。
2. 在「权限」步骤点「打开系统设置」。系统设置会跳到「隐私与安全性 › 完整磁盘访问」，旁边浮出一张卡片；
   把卡片里的 **AutoCodeBar** 拖进列表并打开开关。卡片检测到授权后会自动收起。
3. 如果系统设置提示需要重新打开应用，或引导窗口 10 秒后仍显示未授权，点「重新启动」。
4. 通知是可选的。允许后复制成功会有横幅提醒；不允许则只在菜单栏显示。
5. 点「完成」。之后所有设置都在「菜单栏图标 › 齿轮 › 设置…」里。

**iPhone 上的短信**：推荐在 iPhone「设置 › 信息 › 短信转发」中勾选这台 Mac，短信会进入「信息」应用，
AutoCodeBar 走短信来源。如果你使用 iPhone 镜像，iPhone 的通知会送达 Mac 的通知中心，可以在
「设置 › 来源」里开启实验性的「通知中心」来源。

**一键填入**：想让验证码直接落进输入框，在「设置 › 通用」打开「在输入框旁显示填入按钮」。首次打开会弹出与完整磁盘访问
同款的引导卡片，把里面的 AutoCodeBar 拖进「隐私与安全性 › 辅助功能」列表即可。不开也不影响，验证码照常进剪贴板，⌘V 粘贴。

**暂停**：面板右上角的暂停按钮会停止所有来源，图标变为空心钥匙；重新启动应用会自动恢复。

<p align="center">
  <img src="Resources/Screenshots/onboarding.png" width="900" alt="首次启动引导：完整磁盘访问与通知两步权限" />
</p>

## 已验证范围

| 能力 | 当前状态 | 边界 |
| --- | --- | --- |
| 短信 / iMessage 读取 | 实机验证，macOS 15.7 | 只处理收到的消息（`is_from_me = 0`）；正文优先读 `text`，为空时解析 `attributedBody` 的 typedstream；超过 10 分钟的消息忽略 |
| 邮件读取 | 实机验证 | 只监听 Apple Mail 本地存储的 `.emlx`；跳过 `.partial.emlx`；正文优先 `text/plain`，其次 HTML 转文本；超过 15 分钟的邮件忽略 |
| 通知中心 | 实验 | 读取 `group.com.apple.usernoted` 数据库；解析 `titl` / `subt` / `body`；默认忽略 Telegram 等聊天应用；私有格式，系统升级后可能失效 |
| 验证码识别 | 39 条语料回归测试 | 4–8 位字母数字且至少含 1 位数字；先命中关键词再打分；金额、单位、年份、尾号、订单号、URL 内的数字会被排除 |
| 去重 | 单元测试 | 同一验证码 300 秒内只接受一次，不区分来源 |
| 剪贴板 | 实机验证 | 覆盖剪贴板当前内容；带机密标记 |
| 一键填入 | 实机验证（Chrome 单行框与 6 格分框） | 默认关闭；需要辅助功能权限；只在验证码到达后 60 秒内、且焦点在文本输入框（AXTextField / AXTextArea / AXComboBox / AXSearchField）时显示；密码框不代填 |

## 隐私与网络

| 数据 | AutoCodeBar 的处理方式 |
| --- | --- |
| 短信、邮件、通知内容 | 只读打开本机数据文件，在内存中解析，不写入任何地方 |
| 验证码历史 | 只在内存中，最多 20 条，退出应用即清空 |
| 剪贴板 | 写入验证码本身，并附 `org.nspasteboard.ConcealedType` 标记 |
| 设置 | 保存在本机 `UserDefaults` |
| 网络 | 仅 Sparkle 更新检查会访问 GitHub Pages 上的签名 appcast 与 GitHub Releases（每天一次，可在设置里关闭）；没有服务器、分析 SDK 或其他网络请求 |
| 权限 | 完整磁盘访问（读取「信息」与「邮件」数据，必需）；通知（可选）；辅助功能（可选，仅「一键填入」用来把验证码键入当前输入框） |

应用内的 GitHub 与 X 按钮只会在默认浏览器打开对应页面。

## 开发

项目使用 SwiftPM，两个 target：`AutoCodeBarCore`（纯逻辑，可测）与 `AutoCodeBar`（SwiftUI / AppKit 应用）。
常用任务写在 [`mise.toml`](mise.toml)：

| 命令 | 用途 |
| --- | --- |
| `mise run build` | 构建全部 target |
| `mise run test` | 运行识别语料、MIME、typedstream、管线、设置迁移等测试 |
| `mise run i18n` | 检查中英文字符串表的键值与占位符 |
| `mise run release-config` | 检查 Sparkle 与发布元数据，不读取任何密钥 |
| `mise run bundle` | 组装并签名本机架构的 `dist/AutoCodeBar.app` |
| `mise run bundle-universal` | 组装并签名 Universal 2 App |
| `mise run release-dry-run` | 用 Developer ID 生成未公证的 Universal 2 DMG |
| `mise run release` | 从干净 tag 构建、签名、公证、staple 并生成签名 appcast |
| `mise run verify` | 构建、测试、检查本地化与发布配置并组装 App |
| `./script/build_and_run.sh` | 不用 mise 时的开发入口：组装、签名并启动 |
| `./script/build_and_run.sh --install` | 安装到 Applications 并启动 |
| `./script/build_and_run.sh --logs` | 启动并跟随应用日志 |
| `./script/build_and_run.sh --debug` | debug 构建并用 lldb 启动 |
| `./script/build_and_run.sh --verify` | 构建、启动并确认进程存活 |
| `swift script/make_icon_artwork.swift Resources/AppIcon.png` | 程序化重绘图标主稿 |
| `swift script/make_icon.swift Resources/AppIcon.png Resources/AppIcon.icns Resources/Screenshots/app-icon-rounded.png` | 由主稿生成 `.icns` 与 README 用的圆角图 |
| `swift build && .build/debug/AutoCodeBar --snapshot-popover out.png` | 用示例数据把面板渲染成 PNG（仅 debug 构建；菜单栏管理器会把图标藏到屏外，程序化点开截图不可靠） |

```text
Sources/
├── AutoCodeBarCore/
│   ├── Domain/        SourceKind、SourceStatus、Candidate、CodeEvent、AppSettings
│   ├── Extraction/    TextNormalizer → ExtractionRules → CodeExtractor（打分识别）
│   ├── Pipeline/      CodePipeline、Deduplicator、Clipboard、History、Keystrokes
│   ├── Sources/       三个监听器 + FSEventsWatcher、SQLite、TypedStreamText、Emlx/MIME 解析
│   └── Permissions/   PermissionProbe、SystemSettingsLinks、DarwinPaths
└── AutoCodeBar/
    ├── App/           AutoCodeBarApp、AppDelegate、AppState
    ├── MenuBar/       菜单栏图标与面板
    ├── Settings/      设置窗口五页
    ├── Onboarding/    首次启动引导
    ├── Permissions/   完整磁盘访问与辅助功能引导卡片
    ├── QuickFill/     填入卡片、聚焦输入框探测
    ├── Support/       Sparkle 更新、登录启动、通知、重启
    └── Design/        Theme 令牌与通用组件
Resources/Localizations/  zh-Hans 与 en 字符串表
Tests/                 语料、解析器、管线、迁移测试
```

## 参与项目

欢迎提交 Issue 和 Pull Request。报告识别失败时，请附上脱敏后的消息文本（把无关数字改掉即可）、
期望识别出的验证码、来源类型（短信 / 邮件 / 通知）与 macOS 版本；不要上传真实手机号、邮箱或未过期的验证码。

- [报告问题](https://github.com/qzz0518/AutoCodeBar/issues)
- [查看源码](https://github.com/qzz0518/AutoCodeBar)
- [在 X 关注 @zerah_eth](https://x.com/zerah_eth)

## 致谢

- [LeeeSe/MessAuto](https://github.com/LeeeSe/MessAuto)：「关键词门控 + 就近候选」的识别思路来源；AutoCodeBar 的
  Swift 实现为独立编写。

## 许可证

项目代码以 [MIT License](LICENSE) 发布。Apple、macOS、iMessage 等商标归各自权利人所有。
