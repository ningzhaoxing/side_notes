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
  SIDE_NOTES_REQUEST_QUIT_EXISTING=1 "$SOURCE_APP/Contents/MacOS/SideNotes" >/dev/null 2>&1 || true
  sleep 0.5
  osascript -e 'tell application id "com.ningzhaoxing.sidenotes" to quit' >/dev/null 2>&1 || true
  killall SideNotes >/dev/null 2>&1 || true
  sleep 0.5
  killall -9 SideNotes >/dev/null 2>&1 || true
  sleep 0.5

  LOCK_FILE="$HOME/Library/Application Support/SideNotes/SideNotes.lock"
  if command -v lsof >/dev/null 2>&1 && lsof "$LOCK_FILE" >/dev/null 2>&1; then
    echo "SideNotes is still running. Use the card's 退出 button or the side handle menu to quit, then run this installer again." >&2
    exit 1
  fi
fi

mkdir -p "$INSTALL_DIR"
rm -rf "$TARGET_APP"
ditto "$SOURCE_APP" "$TARGET_APP"
xattr -cr "$TARGET_APP" 2>/dev/null || true
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$TARGET_APP" >/dev/null
fi

echo "$TARGET_APP"
