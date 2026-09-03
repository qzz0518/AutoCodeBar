<!-- sparkle-sign-warning:
IMPORTANT: This file was signed by Sparkle. Any modifications to this file requires updating signatures in appcasts that reference this file! This will involve re-running generate_appcast or sign_update.
-->
<p align="center">
  <img src="https://raw.githubusercontent.com/qzz0518/AutoCodeBar/main/Resources/Screenshots/app-icon-rounded.png" width="96" alt="AutoCodeBar icon" />
</p>

<h2 align="center">AutoCodeBar 2.0.1</h2>
<p align="center">修复短信与通知中心来源经常收不到新消息的问题。</p>

## 更新日志

1. **短信与通知中心不再漏消息**：系统守护进程写入 `chat.db` 与通知数据库时，macOS 并不会为这两个文件产生文件系统事件，之前只依赖 FSEvents 的监听会一直等不到新消息。现在在文件事件之外每秒比对一次数据库与 WAL 文件的修改时间和大小，有变化才读取，延迟不超过一秒，开销可以忽略。
2. **更快的提前触发**：收到新短信时「信息」通常会顺带更新昵称缓存，这类事件现在也会触发一次读取。
3. **更清楚的日志**：短信来源在统一日志里记录每次读取到的行数与跳过原因（`dev.qiuzezheng.AutoCodeBar` 子系统），方便排查。

## Changelog

1. **SMS and Notification Center no longer miss messages**: macOS emits no file system events when its daemons write `chat.db` or the notification database, so a watcher that relied on FSEvents alone could wait forever. Alongside file events, the sources now compare the modification time and size of the database and its WAL once a second and read only when something changed. Latency stays under a second at negligible cost.
2. **Earlier trigger**: Messages usually updates its nickname cache when a message arrives; those events now also trigger a read.
3. **Clearer logging**: the SMS source records rows read and skip reasons in the unified log (subsystem `dev.qiuzezheng.AutoCodeBar`).

## 安装 / Install

### Homebrew

```bash
brew install --cask qzz0518/tap/autocodebar
```

已安装的用户执行 `brew upgrade --cask autocodebar`，或等待应用内的 Sparkle 更新提示。

Existing users can run `brew upgrade --cask autocodebar` or accept the in-app Sparkle update.

### DMG

下载下方的 `AutoCodeBar-2.0.1.dmg`，打开后将 AutoCodeBar 拖入 Applications。

Download `AutoCodeBar-2.0.1.dmg` below, open it, and drag AutoCodeBar into Applications.

## 兼容性 / Compatibility

- macOS 14 或更高版本 / macOS 14 or later
- Universal 2（Apple Silicon + Intel）
