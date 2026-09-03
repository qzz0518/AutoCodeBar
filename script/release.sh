#!/usr/bin/env bash
# Build the one canonical release DMG used by GitHub, Sparkle and Homebrew.
# The source commit and tag must already exist; secrets stay in the login
# keychain and are referenced only by identity hash or profile name.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")}"
BUILD_NUMBER="${BUILD_NUMBER:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/Resources/Info.plist")}"
TAG="${TAG:-v$VERSION}"
ARCHS="${ARCHS:-arm64 x86_64}"
NOTARIZE="${NOTARIZE:-1}"
GENERATE_APPCAST="${GENERATE_APPCAST:-1}"
REQUIRE_TAG="${REQUIRE_TAG:-1}"
REQUIRE_CLEAN="${REQUIRE_CLEAN:-1}"
# Name of the `notarytool store-credentials` profile in the login keychain.
# Override it if your profile is stored under a different name.
NOTARY_PROFILE="${NOTARY_PROFILE:-AutoCodeBar-Notary}"
APP="$ROOT/dist/AutoCodeBar.app"
APP_ZIP="$ROOT/dist/AutoCodeBar-$VERSION.app.zip"
DMG="$ROOT/dist/AutoCodeBar-$VERSION.dmg"
UPDATES_DIR="$ROOT/dist/updates"

if [ "$REQUIRE_CLEAN" = "1" ] && [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
	echo "release requires a clean Git working tree" >&2
	exit 1
fi
if [ "$REQUIRE_TAG" = "1" ]; then
	HEAD_TAG="$(git -C "$ROOT" describe --tags --exact-match HEAD 2>/dev/null || true)"
	if [ "$HEAD_TAG" != "$TAG" ]; then
		echo "HEAD must be tagged $TAG before creating a release" >&2
		exit 1
	fi
fi

IDENTITY="${IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk '/Developer ID Application:/ {print $2; exit}')}"
if [ -z "$IDENTITY" ]; then
	echo "no valid Developer ID Application identity was found" >&2
	exit 1
fi

notarize_artifact() {
	local artifact="$1"
	local label="$2"
	local result="$ROOT/dist/notary-$label-result.json"
	local log="$ROOT/dist/notary-$label-log.json"
	local submission_id status

	xcrun notarytool submit "$artifact" \
		--keychain-profile "$NOTARY_PROFILE" \
		--wait --output-format json > "$result"
	submission_id="$(plutil -extract id raw -o - "$result")"
	status="$(plutil -extract status raw -o - "$result")"
	xcrun notarytool log "$submission_id" \
		--keychain-profile "$NOTARY_PROFILE" > "$log"
	if [ "$status" != "Accepted" ]; then
		echo "Apple notarization status for $label: $status" >&2
		echo "see $log" >&2
		exit 1
	fi
}

if [ "$NOTARIZE" = "1" ]; then
	# Fail before the expensive Universal 2 build if the keychain profile is
	# missing, expired or tied to the wrong developer team.
	xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null
fi

VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" ARCHS="$ARCHS" \
	IDENTITY="$IDENTITY" DISTRIBUTION=1 CONFIG=release \
	"$ROOT/script/make_app.sh"

# The app needs its own stapled ticket before it is sealed inside the DMG.
# That preserves offline Gatekeeper validation after Finder, Homebrew or
# Sparkle copies the bundle out of the mounted image.
if [ "$NOTARIZE" = "1" ]; then
	rm -f "$APP_ZIP"
	ditto -c -k --keepParent "$APP" "$APP_ZIP"
	notarize_artifact "$APP_ZIP" app
	xcrun stapler staple "$APP"
	xcrun stapler validate "$APP"
fi

"$ROOT/script/make_dmg.sh" \
	"$APP" "$DMG" "$VERSION" "$ROOT/Resources/DMG/background.png"
codesign --force --sign "$IDENTITY" --timestamp "$DMG"
hdiutil verify "$DMG"

if [ "$NOTARIZE" = "1" ]; then
	notarize_artifact "$DMG" dmg
	xcrun stapler staple "$DMG"
	xcrun stapler validate "$DMG"
else
	echo "warning: NOTARIZE=0; this DMG is not publishable" >&2
fi

shasum -a 256 "$DMG" > "$DMG.sha256"

if [ "$GENERATE_APPCAST" = "1" ]; then
	if [ "$NOTARIZE" != "1" ]; then
		echo "refusing to generate a production appcast from an unstapled DMG" >&2
		exit 1
	fi
	SPARKLE_TOOLS="$ROOT/.build/artifacts/sparkle/Sparkle/bin"
	if [ ! -x "$SPARKLE_TOOLS/generate_appcast" ]; then
		echo "missing Sparkle generate_appcast tool; run swift package resolve" >&2
		exit 1
	fi
	rm -rf "$UPDATES_DIR"
	mkdir -p "$UPDATES_DIR"
	if [ -f "$ROOT/site/appcast.xml" ]; then
		cp "$ROOT/site/appcast.xml" "$UPDATES_DIR/appcast.xml"
	fi
	# The release notes are signed alongside the DMG, so the feed can point at
	# them without giving an attacker a place to inject unsigned content.
	# AutoCodeBar-<version>.md is the default (English) text; two-letter
	# language variants such as AutoCodeBar-<version>.zh.md become
	# xml:lang entries that Sparkle picks by the user's language.
	for NOTES in "$ROOT/site/AutoCodeBar-$VERSION.md" "$ROOT/site/AutoCodeBar-$VERSION".??.md; do
		[ -f "$NOTES" ] && cp "$NOTES" "$UPDATES_DIR/"
	done
	cp "$DMG" "$UPDATES_DIR/"
	# One DMG per run and no delta packages: every release lives under its
	# own tag directory, and deltas would need their own uploaded assets.
	"$SPARKLE_TOOLS/generate_appcast" \
		--maximum-deltas 0 \
		--download-url-prefix "https://github.com/qzz0518/AutoCodeBar/releases/download/$TAG/" \
		--release-notes-url-prefix "https://qzz0518.github.io/AutoCodeBar/" \
		"$UPDATES_DIR"
fi

echo "release artifact: $DMG"
echo "checksum: $DMG.sha256"
if [ -f "$UPDATES_DIR/appcast.xml" ]; then
	echo "signed appcast: $UPDATES_DIR/appcast.xml"
fi
