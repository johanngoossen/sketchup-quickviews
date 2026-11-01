#!/bin/sh
# Builds the release files into dist/:
#   jg_quickviews-<v>.rbz                 (Extension Manager, all platforms)
#   QuickViews-<v>-macOS.pkg              (macOS installer, unsigned)
#   QuickViews-<v>-Windows-Installer.cmd  (Windows installer, single file)
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(sed -n "s/.*VERSION = '\([^']*\)'.*/\1/p" "$REPO/src/jg_quickviews.rb")"
DIST="$REPO/dist"
RBZ="$DIST/jg_quickviews-$VERSION.rbz"
sh "$REPO/tools/build_rbz.sh" > /dev/null

# --- macOS: scripts-only component package wrapped in a product archive ---
WORK="$(mktemp -d -t quickviews)"
mkdir -p "$WORK/scripts/payload" "$WORK/resources"
cp "$REPO/installer/macos/postinstall" "$WORK/scripts/"
(cd "$WORK/scripts/payload" && unzip -q "$RBZ")
xattr -cr "$WORK" # no AppleDouble ._ files in the package
export COPYFILE_DISABLE=1
cp "$REPO/installer/macos/welcome.html" "$REPO/installer/macos/conclusion.html" "$WORK/resources/"
pkgbuild --quiet --nopayload --scripts "$WORK/scripts" \
  --identifier com.johanngoossen.quickviews --version "$VERSION" \
  "$WORK/quickviews-component.pkg"
sed "s/@VERSION@/$VERSION/g" "$REPO/installer/macos/distribution.xml" > "$WORK/distribution.xml"
PKG="$DIST/QuickViews-$VERSION-macOS.pkg"
productbuild --quiet --distribution "$WORK/distribution.xml" --resources "$WORK/resources" \
  --package-path "$WORK" "$PKG"
echo "$PKG"

# --- Windows: batch + PowerShell with the .rbz embedded as base64 (CRLF) ---
CMD="$DIST/QuickViews-$VERSION-Windows-Installer.cmd"
{
  sed "s/@VERSION@/$VERSION/g" "$REPO/installer/windows/installer_template.cmd"
  echo '#PAYLOAD#'
  base64 -b 76 -i "$RBZ"
} | sed 's/$/\r/' > "$CMD"
echo "$CMD"
echo "$RBZ"
