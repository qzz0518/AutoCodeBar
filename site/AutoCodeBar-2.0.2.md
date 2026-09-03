<!-- sparkle-sign-warning:
IMPORTANT: This file was signed by Sparkle. Any modifications to this file requires updating signatures in appcasts that reference this file! This will involve re-running generate_appcast or sign_update.
-->
The app identifier is now cc.zerah.AutoCodeBar, and personal information has been removed from logs and release notes.

- **New app identifier**: macOS treats this as a new app. After the first launch, add AutoCodeBar again under Privacy & Security › Full Disk Access; the guide card in the panel walks you through it.
- **Upgrading from 2.0.1**: the in-app updater cannot install across identifiers. Run `brew upgrade --cask autocodebar` or install the new DMG over the old app. Settings need to be configured once more.
- **Logging**: the log subsystem and internal queue names no longer contain personal information.
