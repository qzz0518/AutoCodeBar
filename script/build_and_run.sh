#!/usr/bin/env bash
# Local convenience wrapper: assemble the app bundle, then run, install or
# inspect it. Everything about assembly and signing lives in make_app.sh.
set -euo pipefail

MODE="${1:-run}"
APP_NAME="AutoCodeBar"
BUNDLE_ID="dev.qiuzezheng.AutoCodeBar"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

CONFIG="release"
if [[ "$MODE" == "--debug" || "$MODE" == "debug" ]]; then
	CONFIG="debug"
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

CONFIG="$CONFIG" "$ROOT_DIR/script/make_app.sh"

open_app() {
	/usr/bin/open -n "$APP_BUNDLE"
}

install_app() {
	local install_dir="/Applications"
	if [[ ! -w "$install_dir" ]]; then
		install_dir="$HOME/Applications"
		mkdir -p "$install_dir"
	fi

	local installed_app="$install_dir/$APP_NAME.app"
	rm -rf "$installed_app"
	/usr/bin/ditto "$APP_BUNDLE" "$installed_app"
	/usr/bin/touch "$installed_app"
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$installed_app" >/dev/null 2>&1 || true
	printf '%s' "$installed_app"
}

case "$MODE" in
	run)
		open_app
		;;
	--install|install)
		INSTALLED_APP="$(install_app)"
		echo "已安装到 $INSTALLED_APP。首次运行请在「系统设置 › 隐私与安全性 › 完整磁盘访问」中启用 AutoCodeBar。"
		/usr/bin/open -n "$INSTALLED_APP"
		;;
	--debug|debug)
		lldb -- "$APP_BINARY"
		;;
	--logs|logs)
		open_app
		/usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\" OR subsystem == \"$BUNDLE_ID\""
		;;
	--verify|verify)
		open_app
		sleep 2
		pgrep -x "$APP_NAME" >/dev/null
		echo "$APP_NAME 已启动（pid $(pgrep -x "$APP_NAME" | head -n 1)）"
		;;
	*)
		echo "usage: $0 [run|--install|--debug|--logs|--verify]" >&2
		exit 2
		;;
esac
