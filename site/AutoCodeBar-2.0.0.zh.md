<!-- sparkle-sign-warning:
IMPORTANT: This file was signed by Sparkle. Any modifications to this file requires updating signatures in appcasts that reference this file! This will involve re-running generate_appcast or sign_update.
-->
2.0 是一次全新重写。

- **启动即监听**：不再需要先点开面板；暂停不会被面板刷新撕掉；三个来源各自独立启停、独立恢复。
- **三个数据来源**：「信息」的短信与 iMessage、Apple Mail 的本地邮件，以及实验性的通知中心来源（默认关闭，可覆盖 iPhone 镜像等其他应用的通知）。
- **打分式识别**：按关键词邻近度、字形、行位置和上下文挑出验证码，年份、金额、单号、尾号都会被排除；关键词与正则可在设置里修改，并带实时测试框。
- **菜单栏与通知**：识别到验证码即复制，菜单栏显示 15 秒，可选系统通知；面板保留最近 5 条，悬停即可再次复制。
- **权限引导**：三步引导流程；「完整磁盘访问」提供一张会飞到系统设置窗口并跟随的引导卡片，把应用图标拖进权限列表即可。
- **隐私**：历史只在内存中，最多 20 条，退出即清；验证码写入剪贴板时带机密标记；除更新检查外没有任何网络请求。
- **安全分发**：Developer ID 签名、Apple 公证与 Sparkle 签名更新源。
