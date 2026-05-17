#!/usr/bin/env bash
# Hatch: Swift Package bauen und die App zum Testen starten.
#
# Aufruf:
#   ./build_and_run.sh              Debug-Build, dann starten (im Hintergrund via open)
#   ./build_and_run.sh --release    Release-Build
#   ./build_and_run.sh --no-run     Nur bauen
#   ./build_and_run.sh --foreground App im Vordergrund aus dem Terminal (Log-Ausgabe sichtbar)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

CONFIG="debug"
RUN=true
FOREGROUND=false

for arg in "$@"; do
  case "$arg" in
    --release|-r) CONFIG="release" ;;
    --no-run) RUN=false ;;
    --foreground|-f) FOREGROUND=true ;;
    -h|--help)
      echo "Usage: $0 [--release|-r] [--no-run] [--foreground|-f]"
      exit 0
      ;;
  esac
done

echo "→ swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
EXE="$BIN_DIR/Hatch"

if [[ ! -x "$EXE" ]]; then
  echo "Fehler: Ausführbare Datei nicht gefunden: $EXE" >&2
  exit 1
fi

echo "→ Fertig: $EXE"

if [[ "$RUN" != "true" ]]; then
  exit 0
fi

if [[ "$FOREGROUND" == "true" ]]; then
  echo "→ Starte im Vordergrund (Strg+C beendet die App) …"
  exec "$EXE"
else
  echo "→ Starte App …"
  open "$EXE"
fi
