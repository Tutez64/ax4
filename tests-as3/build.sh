#!/usr/bin/env bash
# Regenerates expected.txt from Flash Player, the reference the converted checks are compared to.
# src/ is compiled with the AIR SDK's mxmlc (ASC 2.0), its ABC 47.16 turned into the 46.16 Flash
# Player 32 reads (abc46.py), and run in the Flash Player projector content debugger, whose traces
# go to ~/.macromedia/Flash_Player/Logs/flashlog.txt (~/mm.cfg needs TraceOutputFileEnable=1).
#
# Usage: tests-as3/build.sh [air-sdk] [flashplayerdebugger]   (AIR_SDK and FLASH_PLAYER_DEBUGGER also work)
set -euo pipefail
cd "$(dirname "$0")"
AIR_SDK="${1:-${AIR_SDK:?pass the AIR SDK directory}}"
PLAYER="${2:-${FLASH_PLAYER_DEBUGGER:?pass the path to flashplayerdebugger}}"
LOG="$HOME/.macromedia/Flash_Player/Logs/flashlog.txt"
grep -qs '^TraceOutputFileEnable=1' "$HOME/mm.cfg" || { echo "add TraceOutputFileEnable=1 to ~/mm.cfg" >&2; exit 1; }
TMP="$(mktemp -d)"
PID=""
trap '[[ -n "$PID" ]] && kill "$PID" 2>/dev/null; rm -rf "$TMP"' EXIT

"$AIR_SDK/bin/mxmlc" -swf-version=32 -compress=false -omit-trace-statements=false \
  -source-path src -source-path flash -output "$TMP/checks.swf" flash/Main.as > /dev/null
python3 -I abc46.py "$TMP/checks.swf" "$TMP/checks46.swf"

rm -f "$LOG"
"$PLAYER" "$TMP/checks46.swf" > /dev/null 2>&1 &
PID=$!
# fscommand("quit") would drop the end of the log: the player is closed once the marker is written
for _ in $(seq 1 300); do
  grep -qs '^#END' "$LOG" && break
  sleep 0.1
done
kill "$PID" 2>/dev/null || true
PID=""
tr -d '\r' < "$LOG" > "$TMP/log.txt"
if ! grep -q '^#END' "$TMP/log.txt"; then
  echo "the checks did not finish in Flash Player:" >&2
  cat "$TMP/log.txt" >&2
  exit 1
fi
sed -n 's/^| //p' "$TMP/log.txt" > expected.txt
echo "expected.txt: $(wc -l < expected.txt) lines"
