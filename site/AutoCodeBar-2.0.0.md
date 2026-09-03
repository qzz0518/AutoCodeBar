<!-- sparkle-sign-warning:
IMPORTANT: This file was signed by Sparkle. Any modifications to this file requires updating signatures in appcasts that reference this file! This will involve re-running generate_appcast or sign_update.
-->
2.0 is a complete rewrite.

- **Monitoring starts with the app**: no need to open the panel first; a manual pause is no longer undone by the panel; each source starts, fails and recovers on its own.
- **Three sources**: SMS and iMessage from Messages, local mail from Apple Mail, and an experimental Notification Center source (off by default) that can also cover iPhone Mirroring and other apps.
- **Scored extraction**: candidates are ranked by keyword proximity, shape, line position and surrounding context, so years, amounts, order numbers and card suffixes are rejected. Keywords and the pattern are editable with a live test field.
- **Menu bar and notifications**: a recognised code is copied immediately, shown in the menu bar for 15 seconds, and optionally announced by a banner. The panel keeps the last five and re-copies on hover.
- **Permission guidance**: a three-step setup flow, plus a Full Disk Access card that flies to the System Settings window, follows it, and hands you a draggable copy of the app icon for the permission list.
- **Privacy**: history lives in memory only, capped at 20 entries and cleared on quit; codes are written to the pasteboard with the concealed-content marker; nothing is sent anywhere except the update check.
- **Secure distribution**: Developer ID signing, Apple notarization and an EdDSA-signed Sparkle update feed.
