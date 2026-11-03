#!/bin/sh
# Builds dist/QuickViews-<version>.rbz from src/ (without development files).
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(sed -n "s/.*VERSION = '\([^']*\)'.*/\1/p" "$REPO/src/jg_quickviews.rb")"
OUT="$REPO/dist/QuickViews-$VERSION.rbz"
mkdir -p "$REPO/dist"
rm -f "$OUT"
cd "$REPO/src"
zip -r -X -q "$OUT" jg_quickviews.rb jg_quickviews -x '*.DS_Store' 'jg_quickviews/ui/dev_mock.js'
echo "$OUT"
unzip -l "$OUT" | tail -n +4 | sed '$d' | sed '$d' | awk '{print "  " $4}'
