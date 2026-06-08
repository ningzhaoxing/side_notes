#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

"$ROOT_DIR/Scripts/build_app.sh" >/dev/null

INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
APP_NAME="SideNotes.app"
SOURCE_APP="$ROOT_DIR/Build/$APP_NAME"
TARGET_APP="$INSTALL_DIR/$APP_NAME"

mkdir -p "$INSTALL_DIR"
rm -rf "$TARGET_APP"
ditto "$SOURCE_APP" "$TARGET_APP"

echo "$TARGET_APP"
