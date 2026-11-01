#!/bin/sh
# Renders the README images (docs/images/*.png) from docs/src/*.html with WebKit.
# The dialog screenshots use the browser mock (src/jg_quickviews/ui/dev_mock.js).
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${TMPDIR:-/tmp}/qv_snapshot_build/snapshot"
mkdir -p "$(dirname "$BIN")"
swiftc -O "$REPO/tools/snapshot.swift" -o "$BIN"
url() { printf 'file://%s%s' "$(printf '%s' "$1" | sed 's/ /%20/g')" "$2"; }
OUT="$REPO/docs/images"
mkdir -p "$OUT"
UI="$REPO/src/jg_quickviews/ui/dialog.html"
"$BIN" "$(url "$UI" '?mock&lang=en')" "$OUT/dialog-light.png" 560 1010 light 1.2
"$BIN" "$(url "$UI" '?mock&lang=en')" "$OUT/dialog-dark.png" 560 1010 dark 1.2
"$BIN" "$(url "$REPO/docs/src/hero.html")" "$OUT/hero.png" 1200 600 light 0.5
"$BIN" "$(url "$REPO/docs/src/frame.html")" "$OUT/frame-preview.png" 1200 560 light 0.5
"$BIN" "$(url "$REPO/docs/src/workflow.html")" "$OUT/workflow.png" 1200 500 light 0.5
"$BIN" "$(url "$REPO/docs/src/dialog.html")" "$OUT/dialog.png" 1200 840 light 0.8
