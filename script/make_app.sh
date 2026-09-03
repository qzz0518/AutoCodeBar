#!/usr/bin/env bash
# Assemble and sign AutoCodeBar.app from the SwiftPM products.
#
# Local development stays fast by building only the host architecture and
# signing ad-hoc. A distribution build passes both architectures, a Developer ID
# identity and DISTRIBUTION=1; every nested code item is then signed explicitly
# with the hardened runtime and a secure timestamp.
set -euo pipefail

CONFIG="${CONFIG:-release}"
DISTRIBUTION="${DISTRIBUTION:-0}"
ARCHS="${ARCHS:-$(uname -m)}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${APP_PATH:-$ROOT/dist/AutoCodeBar.app}"
BUILD_ROOT="${BUILD_ROOT:-$ROOT/.build/autocodebar-bundle}"
SOURCE_INFO="$ROOT/Resources/Info.plist"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_INFO")}"
BUILD_NUMBER="${BUILD_NUMBER:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SOURCE_INFO")}"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE_INFO")"

# Preference order: an explicit identity, then a Developer ID, then a
# development certificate, then ad-hoc.
select_identity() {
	if [ -n "${CODESIGN_IDENTITY:-}" ]; then
		printf '%s' "$CODESIGN_IDENTITY"
		return
	fi
	local listing developer_id apple_development
	listing="$(/usr/bin/security find-identity -v -p codesigning 2>/dev/null || true)"
	developer_id="$(printf '%s\n' "$listing" | /usr/bin/sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -n 1)"
	if [ -n "$developer_id" ]; then
		printf '%s' "$developer_id"
		return
	fi
	apple_development="$(printf '%s\n' "$listing" | /usr/bin/sed -n 's/.*"\(Apple Development: .*\)"/\1/p' | head -n 1)"
	if [ -n "$apple_development" ]; then
		printf '%s' "$apple_development"
		return
	fi
	printf '%s' "-"
}

IDENTITY="${IDENTITY:-$(select_identity)}"

if [ "$DISTRIBUTION" = "1" ] && [ "$IDENTITY" = "-" ]; then
	echo "DISTRIBUTION=1 requires a Developer ID Application identity" >&2
	exit 1
fi

read -r -a ARCH_LIST <<< "$ARCHS"
if [ "${#ARCH_LIST[@]}" -eq 0 ]; then
	echo "ARCHS must contain at least one architecture" >&2
	exit 1
fi

BIN_DIRS=()
BINARIES=()
for ARCH in "${ARCH_LIST[@]}"; do
	case "$ARCH" in
		arm64|x86_64) ;;
		*) echo "unsupported architecture: $ARCH" >&2; exit 1 ;;
	esac
	SCRATCH="$BUILD_ROOT/$ARCH"
	swift build -c "$CONFIG" \
		--triple "$ARCH-apple-macosx" \
		--scratch-path "$SCRATCH" \
		--product AutoCodeBar
	BIN_DIR="$(swift build -c "$CONFIG" \
		--triple "$ARCH-apple-macosx" \
		--scratch-path "$SCRATCH" \
		--show-bin-path)"
	BIN="$BIN_DIR/AutoCodeBar"
	if [ ! -x "$BIN" ]; then
		echo "missing AutoCodeBar executable for $ARCH: $BIN" >&2
		exit 1
	fi
	if ! lipo -archs "$BIN" | tr ' ' '\n' | grep -Fxq "$ARCH"; then
		echo "AutoCodeBar executable does not contain requested architecture $ARCH" >&2
		exit 1
	fi
	BIN_DIRS+=("$BIN_DIR")
	BINARIES+=("$BIN")
done

SPARKLE_FRAMEWORK="${BIN_DIRS[0]}/Sparkle.framework"
if [ ! -d "$SPARKLE_FRAMEWORK" ]; then
	echo "missing embedded framework: $SPARKLE_FRAMEWORK" >&2
	exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"
if [ "${#BINARIES[@]}" -eq 1 ]; then
	cp "${BINARIES[0]}" "$APP/Contents/MacOS/AutoCodeBar"
else
	lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/AutoCodeBar"
fi
ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"

cp "$SOURCE_INFO" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Bundle.main must own the localizations. SwiftPM's Bundle.module points back
# into the build directory and does not survive a standalone .app.
shopt -s nullglob
for LPROJ in "$ROOT/Resources/Localizations"/*.lproj; do
	ditto "$LPROJ" "$APP/Contents/Resources/$(basename "$LPROJ")"
done
shopt -u nullglob

if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
	cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
if [ -d "$ROOT/Resources/Licenses" ]; then
	ditto "$ROOT/Resources/Licenses" "$APP/Contents/Resources/Licenses"
fi
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"
cp "$ROOT/THIRD-PARTY-NOTICES.md" "$APP/Contents/Resources/THIRD-PARTY-NOTICES.md"

# SwiftPM links Sparkle through @rpath. A shell-assembled bundle does not
# inherit Xcode's runpath search list, so add the conventional app framework
# location before any signature exists.
if ! otool -l "$APP/Contents/MacOS/AutoCodeBar" | grep -Fq '@executable_path/../Frameworks'; then
	install_name_tool -add_rpath '@executable_path/../Frameworks' "$APP/Contents/MacOS/AutoCodeBar"
fi

# A distributable binary must never reveal the builder's checkout path. Keep
# this as a bundle invariant so a future resource loader cannot reintroduce it.
if [ "$CONFIG" = "release" ]; then
	REPOSITORY_PATH_HITS="$(strings "$APP/Contents/MacOS/AutoCodeBar" | grep -F "$ROOT" || true)"
	if [ -n "$REPOSITORY_PATH_HITS" ]; then
		echo "release binary contains the absolute repository path" >&2
		exit 1
	fi
fi

for ARCH in "${ARCH_LIST[@]}"; do
	for CODE in \
		"$APP/Contents/MacOS/AutoCodeBar" \
		"$APP/Contents/Frameworks/Sparkle.framework/Versions/Current/Sparkle"; do
		if ! lipo -archs "$CODE" | tr ' ' '\n' | grep -Fxq "$ARCH"; then
			echo "$(basename "$CODE") is missing requested architecture $ARCH" >&2
			exit 1
		fi
	done
done

BASE_FLAGS=(--force --sign "$IDENTITY")
if [ "$DISTRIBUTION" = "1" ]; then
	BASE_FLAGS+=(--options runtime --timestamp)
fi

# Nested code keeps its own identifier; only the outer bundle is pinned to the
# app's bundle id so the designated requirement stays stable across rebuilds.
sign_nested() {
	codesign "${BASE_FLAGS[@]}" "$@"
}

# Sparkle carries executable code several levels below the framework. Signing
# only the outer framework, or leaning on --deep, leaves an unverifiable and
# non-notarizable bundle. Downloader.xpc keeps its upstream entitlement
# metadata; everything else is signed fresh, from the inside out. The app is
# not sandboxed, so no entitlements are supplied.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
SPARKLE_VERSION="$SPARKLE/Versions/Current"
sign_nested --preserve-metadata=entitlements "$SPARKLE_VERSION/XPCServices/Downloader.xpc"
sign_nested "$SPARKLE_VERSION/XPCServices/Installer.xpc"
sign_nested "$SPARKLE_VERSION/Autoupdate"
sign_nested "$SPARKLE_VERSION/Updater.app"
sign_nested "$SPARKLE"
codesign "${BASE_FLAGS[@]}" --identifier "$BUNDLE_ID" "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"

echo "built $APP"
echo "version $VERSION ($BUILD_NUMBER)"
echo "architectures $(lipo -archs "$APP/Contents/MacOS/AutoCodeBar")"
if [ "$DISTRIBUTION" = "1" ]; then
	echo "signed for Developer ID distribution"
elif [ "$IDENTITY" = "-" ]; then
	echo "signed ad-hoc for local development"
	echo "⚠️  使用 ad-hoc 签名：每次重新构建后都需要重新授予「完整磁盘访问」"
else
	echo "signed for local development with $IDENTITY"
fi
