#!/usr/bin/env bash
# Fast, secret-free checks for the metadata that ties Sparkle, the app bundle
# and the disk image together. This belongs in ordinary CI; signing and
# notarization stay explicit release-only operations.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO="$ROOT/Resources/Info.plist"
DMG_BACKGROUND="$ROOT/Resources/DMG/background.png"
APP_LICENSE="$ROOT/LICENSE"
THIRD_PARTY_NOTICES="$ROOT/THIRD-PARTY-NOTICES.md"
SPARKLE_LICENSE="$ROOT/Resources/Licenses/Sparkle-LICENSE.txt"

plutil -lint "$INFO" >/dev/null

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO")"
FEED_URL="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$INFO")"
PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$INFO")"

case "$FEED_URL" in
	https://*) ;;
	*) echo "SUFeedURL must use HTTPS: $FEED_URL" >&2; exit 1 ;;
esac

KEY_BYTES="$(printf '%s' "$PUBLIC_KEY" | base64 --decode 2>/dev/null | wc -c | tr -d ' ')"
if [ "$KEY_BYTES" != "32" ]; then
	echo "SUPublicEDKey must decode to a 32-byte Ed25519 public key" >&2
	exit 1
fi

for BOOLEAN_KEY in SURequireSignedFeed SUVerifyUpdateBeforeExtraction SUEnableAutomaticChecks LSUIElement; do
	if [ "$(/usr/libexec/PlistBuddy -c "Print :$BOOLEAN_KEY" "$INFO")" != "true" ]; then
		echo "$BOOLEAN_KEY must be enabled" >&2
		exit 1
	fi
done

if ! grep -Fq '.package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.9.6")' "$ROOT/Package.swift"; then
	echo "Sparkle must remain pinned to reviewed version 2.9.6" >&2
	exit 1
fi

for REQUIRED_SCRIPT in "$ROOT/script/make_app.sh" "$ROOT/script/make_dmg.sh" "$ROOT/script/release.sh"; do
	if [ ! -x "$REQUIRED_SCRIPT" ]; then
		echo "$REQUIRED_SCRIPT must be executable" >&2
		exit 1
	fi
done

for REQUIRED_FILE in "$APP_LICENSE" "$THIRD_PARTY_NOTICES" "$SPARKLE_LICENSE"; do
	if [ ! -s "$REQUIRED_FILE" ]; then
		echo "missing required distribution resource: $REQUIRED_FILE" >&2
		exit 1
	fi
done

if [ ! -f "$DMG_BACKGROUND" ]; then
	echo "missing Finder background: $DMG_BACKGROUND" >&2
	exit 1
fi
DMG_WIDTH="$(sips -g pixelWidth "$DMG_BACKGROUND" 2>/dev/null | awk '/pixelWidth:/ {print $2}')"
DMG_HEIGHT="$(sips -g pixelHeight "$DMG_BACKGROUND" 2>/dev/null | awk '/pixelHeight:/ {print $2}')"
if [ "$DMG_WIDTH" != "1520" ] || [ "$DMG_HEIGHT" != "1040" ]; then
	echo "DMG background must be exactly 1520x1040 pixels, got ${DMG_WIDTH}x${DMG_HEIGHT}" >&2
	exit 1
fi

# Sparkle renders the release notes as Markdown in safe mode: inline HTML is
# shown literally, so the notes served from site/ must stay plain Markdown.
for NOTES in "$ROOT"/site/AutoCodeBar-*.md; do
	[ -f "$NOTES" ] || continue
	if grep -Eq '<(p|img|h[1-6]|div|span|br|a|table|center)[ >/]' "$NOTES"; then
		echo "release notes must not contain HTML tags: $NOTES" >&2
		exit 1
	fi
done

if git -C "$ROOT" ls-files | grep -Eq '\.(p12|pem|key|cer|p8)$'; then
	echo "signing material must not be tracked by Git" >&2
	exit 1
fi

echo "Release configuration validation passed: $BUNDLE_ID, Sparkle 2.9.6, signed HTTPS feed."
