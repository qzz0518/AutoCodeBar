<!-- sparkle-sign-warning:
IMPORTANT: This file was signed by Sparkle. Any modifications to this file requires updating signatures in appcasts that reference this file! This will involve re-running generate_appcast or sign_update.
-->
Fixes the SMS and Notification Center sources frequently missing new messages.

- **No more missed messages**: macOS emits no file system events when its daemons write the Messages database or the notification database, so a watcher that relied on file events alone could wait forever. The sources now compare the modification time and size of each database and its WAL once a second and read only when something changed. Latency stays under a second at negligible cost.
- **Earlier trigger**: Messages usually updates its nickname cache when a message arrives; those events now also trigger a read.
- **Clearer logging**: the SMS source records rows read and skip reasons for troubleshooting.
