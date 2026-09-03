<!-- sparkle-sign-warning:
IMPORTANT: This file was signed by Sparkle. Any modifications to this file requires updating signatures in appcasts that reference this file! This will involve re-running generate_appcast or sign_update.
-->
修复短信与通知中心来源经常收不到新消息的问题。

- **短信与通知中心不再漏消息**：macOS 在系统守护进程写入「信息」数据库和通知数据库时不会产生文件系统事件，之前只依赖文件事件的监听会一直等不到新消息。现在每秒比对一次数据库与 WAL 文件的修改时间和大小，有变化才读取，延迟不超过一秒，开销可以忽略。
- **更快的提前触发**：收到新短信时「信息」通常会顺带更新昵称缓存，这类事件现在也会触发一次读取。
- **更清楚的日志**：短信来源在统一日志里记录每次读取到的行数与跳过原因，方便排查。
