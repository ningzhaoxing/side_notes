#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

"$ROOT_DIR/Scripts/build_app.sh" >/dev/null

INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
APP_NAME="SideNotes.app"
SOURCE_APP="$ROOT_DIR/Build/$APP_NAME"
TARGET_APP="$INSTALL_DIR/$APP_NAME"

if [[ "${SIDENOTES_SKIP_QUIT_RUNNING:-0}" != "1" ]]; then
  osascript -e 'tell application id "com.ningzhaoxing.sidenotes" to quit' >/dev/null 2>&1 || true
  killall SideNotes >/dev/null 2>&1 || true
  sleep 0.5
  killall -9 SideNotes >/dev/null 2>&1 || true
  sleep 0.5
fi

mkdir -p "$INSTALL_DIR"
rm -rf "$TARGET_APP"
ditto "$SOURCE_APP" "$TARGET_APP"
xattr -cr "$TARGET_APP" 2>/dev/null || true
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$TARGET_APP" >/dev/null
fi

echo "$TARGET_APP"
