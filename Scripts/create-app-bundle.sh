#!/usr/bin/env bash
# Baut Hatch im Release-Modus und packt eine doppelklickbare Hatch.app nach dist/.
# Erzeugt AppIcon.icns aus Logo.svg für Finder & Dock-Kachel.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Hatch"
DIST="${DIST:-$ROOT/dist}"
APP_BUNDLE="$DIST/${APP_NAME}.app"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/hatch-appicon.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

build_app_icon_icns() {
  local master="$WORK/master-1024.png"
  local iconset="$WORK/AppIcon.iconset"
  swiftc -O "$ROOT/Scripts/GenerateAppIcon.swift" -o "$WORK/genicon" -framework AppKit
  "$WORK/genicon" "$master" "$ROOT/Sources/Hatch/Resources/Logo.svg"
  mkdir "$iconset"
  sips -z 16 16 "$master" --out "$iconset/icon_16x16.png" >/dev/null
  sips -z 32 32 "$master" --out "$iconset/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$master" --out "$iconset/icon_32x32.png" >/dev/null
  sips -z 64 64 "$master" --out "$iconset/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$master" --out "$iconset/icon_128x128.png" >/dev/null
  sips -z 256 256 "$master" --out "$iconset/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$master" --out "$iconset/icon_256x256.png" >/dev/null
  sips -z 512 512 "$master" --out "$iconset/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$master" --out "$iconset/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$master" --out "$iconset/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$iconset" -o "$WORK/AppIcon.icns"
}

cd "$ROOT"
build_app_icon_icns
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

required=( "$BIN_DIR/$APP_NAME" "$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle" "$BIN_DIR/XTerminalUI_XTerminalUI.bundle" "$BIN_DIR/GRDB_GRDB.bundle" )
for p in "${required[@]}"; do
  if [[ ! -e "$p" ]]; then
    echo "Fehlt: $p" >&2
    exit 1
  fi
done

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp -R "$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle" "$APP_BUNDLE/Contents/MacOS/"
cp -R "$BIN_DIR/XTerminalUI_XTerminalUI.bundle" "$APP_BUNDLE/Contents/MacOS/"
cp -R "$BIN_DIR/GRDB_GRDB.bundle" "$APP_BUNDLE/Contents/MacOS/"
cp "$WORK/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$ROOT/Scripts/App-Info.plist" "$APP_BUNDLE/Contents/Info.plist"

chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
echo "Fertig: $APP_BUNDLE"
