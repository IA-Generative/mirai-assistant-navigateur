#!/usr/bin/env bash
# deploy-release.sh — Package, sign and deploy MirAI Recorder to Device Manager
# Usage:
#   BOOTSTRAP_URL=https://dm.example.gouv.fr DM_ADMIN_TOKEN=xxx scripts/deploy-release.sh
#
# Produces:
#   - mirai-browser.crx   (Chrome, signed with PEM key)
#   - mirai-browser.xpi   (Firefox ESR)
#   - updates/mirai-browser.xml  (Chrome auto-update manifest)
#   - updates/mirai-browser.json (Firefox auto-update manifest)
#   - Uploads everything to the DM bootstrap server

set -euo pipefail

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────
SLUG="mirai-browser"
GECKO_ID="mirai-assistant@interieur.gouv.fr"
BOOTSTRAP_URL="${BOOTSTRAP_URL:-https://bootstrap.fake-domain.name}"
ADMIN_TOKEN="${DM_ADMIN_TOKEN:-}"
[ -n "$ADMIN_TOKEN" ] || { echo "ERROR: DM_ADMIN_TOKEN not set"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PRIVATE_DIR="$EXT_DIR/private"
PEM_KEY="$PRIVATE_DIR/mirai-browser-key.pem"
[ -f "$PEM_KEY" ] || { echo "ERROR: PEM key not found at $PEM_KEY"; exit 1; }

BUILD_DIR="/tmp/${SLUG}-build"
OUT_DIR="/tmp/${SLUG}-release"

# Read version from manifest.json
VERSION=$(python3 -c "import json; print(json.load(open('$EXT_DIR/manifest.json'))['version'])")
echo "Building $SLUG v$VERSION..."

# Derive Chrome extension ID from PEM key
EXTENSION_ID=$(openssl rsa -in "$PEM_KEY" -pubout -outform DER 2>/dev/null | python3 -c "
import sys, hashlib
der = sys.stdin.buffer.read()
digest = hashlib.sha256(der).hexdigest()[:32]
print(''.join(chr(ord('a') + int(c, 16)) for c in digest))
")
echo "Extension ID: $EXTENSION_ID"

# ──────────────────────────────────────────────
# 1. Prepare clean build directory
# ──────────────────────────────────────────────
rm -rf "$BUILD_DIR" "$OUT_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR/updates"

# Copy only what the extension needs
cp "$EXT_DIR/manifest.json" "$BUILD_DIR/"
cp "$EXT_DIR/package.json" "$BUILD_DIR/"
cp "$EXT_DIR/README.md" "$BUILD_DIR/" 2>/dev/null || true
cp -r "$EXT_DIR/src/" "$BUILD_DIR/src/"
cp -r "$EXT_DIR/icons/" "$BUILD_DIR/icons/"

# Inject update_url into manifest.json for auto-update
python3 -c "
import json
m = json.load(open('$BUILD_DIR/manifest.json'))
m['update_url'] = '${BOOTSTRAP_URL}/updates/mirai-browser.xml'
m['browser_specific_settings']['gecko']['update_url'] = '${BOOTSTRAP_URL}/updates/mirai-browser.json'
json.dump(m, open('$BUILD_DIR/manifest.json', 'w'), indent=2, ensure_ascii=False)
"

echo "Build directory ready ($(find "$BUILD_DIR" -type f | wc -l | tr -d ' ') files)"

# ──────────────────────────────────────────────
# 2. Package CRX (Chrome)
# ──────────────────────────────────────────────
echo "Packaging CRX..."

# Check for Chrome/Chromium
CHROME_BIN=""
for candidate in \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium" \
  "$(which google-chrome 2>/dev/null || true)" \
  "$(which chromium 2>/dev/null || true)"; do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    CHROME_BIN="$candidate"
    break
  fi
done

if [ -n "$CHROME_BIN" ]; then
  "$CHROME_BIN" --pack-extension="$BUILD_DIR" --pack-extension-key="$PEM_KEY" 2>/dev/null || true
  # Chrome outputs the .crx next to the build dir
  if [ -f "${BUILD_DIR}.crx" ]; then
    mv "${BUILD_DIR}.crx" "$OUT_DIR/${SLUG}-${VERSION}.crx"
    echo "  OK  ${SLUG}-${VERSION}.crx"
  else
    echo "  WARN  CRX packaging failed, skipping"
  fi
else
  echo "  WARN  Chrome/Chromium not found, skipping CRX packaging"
fi

# ──────────────────────────────────────────────
# 3. Package XPI (Firefox)
# ──────────────────────────────────────────────
echo "Packaging XPI..."
(cd "$BUILD_DIR" && zip -r -q "$OUT_DIR/${SLUG}-${VERSION}.xpi" .)
echo "  OK  ${SLUG}-${VERSION}.xpi"

# ──────────────────────────────────────────────
# 4. Generate Chrome update manifest (XML)
# ──────────────────────────────────────────────
cat > "$OUT_DIR/updates/mirai-browser.xml" <<XMLEOF
<?xml version='1.0' encoding='UTF-8'?>
<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
  <app appid='${EXTENSION_ID}'>
    <updatecheck codebase='${BOOTSTRAP_URL}/releases/${SLUG}-${VERSION}.crx'
                 version='${VERSION}' />
  </app>
</gupdate>
XMLEOF
echo "  OK  updates/mirai-browser.xml (appid=${EXTENSION_ID})"

# ──────────────────────────────────────────────
# 5. Generate Firefox update manifest (JSON)
# ──────────────────────────────────────────────
cat > "$OUT_DIR/updates/mirai-browser.json" <<JSONEOF
{
  "addons": {
    "${GECKO_ID}": {
      "updates": [
        {
          "version": "${VERSION}",
          "update_link": "${BOOTSTRAP_URL}/releases/${SLUG}-${VERSION}.xpi"
        }
      ]
    }
  }
}
JSONEOF
echo "  OK  updates/mirai-browser.json (gecko=${GECKO_ID})"

# ──────────────────────────────────────────────
# 6. Deploy to DM bootstrap server
# ──────────────────────────────────────────────
echo ""
echo "Deploying to $BOOTSTRAP_URL..."

# Upload CRX
if [ -f "$OUT_DIR/${SLUG}-${VERSION}.crx" ]; then
  echo -n "  Uploading CRX... "
  curl -sf -X PUT "${BOOTSTRAP_URL}/releases/${SLUG}-${VERSION}.crx" \
    -H "X-Admin-Token: ${ADMIN_TOKEN}" \
    -T "$OUT_DIR/${SLUG}-${VERSION}.crx" \
    && echo "OK" || echo "FAILED"
fi

# Upload XPI
echo -n "  Uploading XPI... "
curl -sf -X PUT "${BOOTSTRAP_URL}/releases/${SLUG}-${VERSION}.xpi" \
  -H "X-Admin-Token: ${ADMIN_TOKEN}" \
  -T "$OUT_DIR/${SLUG}-${VERSION}.xpi" \
  && echo "OK" || echo "FAILED"

# Upload Chrome update manifest
echo -n "  Uploading Chrome update manifest... "
curl -sf -X PUT "${BOOTSTRAP_URL}/updates/mirai-browser.xml" \
  -H "X-Admin-Token: ${ADMIN_TOKEN}" \
  -H "Content-Type: application/xml" \
  -T "$OUT_DIR/updates/mirai-browser.xml" \
  && echo "OK" || echo "FAILED"

# Upload Firefox update manifest
echo -n "  Uploading Firefox update manifest... "
curl -sf -X PUT "${BOOTSTRAP_URL}/updates/mirai-browser.json" \
  -H "X-Admin-Token: ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -T "$OUT_DIR/updates/mirai-browser.json" \
  && echo "OK" || echo "FAILED"

# Deploy config (canary strategy)
echo -n "  Deploying config bundle... "
ZIP_PATH="/tmp/${SLUG}-config.zip"
(cd "$BUILD_DIR" && zip -r -q "$ZIP_PATH" .)
curl -sf -X POST "${BOOTSTRAP_URL}/api/plugins/${SLUG}/deploy" \
  -H "X-Admin-Token: ${ADMIN_TOKEN}" \
  -F "binary=@${ZIP_PATH}" \
  -F "strategy=canary" | python3 -m json.tool 2>/dev/null \
  && echo "" || echo "FAILED"
rm -f "$ZIP_PATH"

# ──────────────────────────────────────────────
# 7. Summary
# ──────────────────────────────────────────────
echo ""
echo "========================================="
echo " Release $SLUG v$VERSION"
echo "========================================="
echo " Extension ID : $EXTENSION_ID"
echo " Gecko ID     : $GECKO_ID"
echo ""
echo " Artifacts:"
ls -lh "$OUT_DIR/"*.crx "$OUT_DIR/"*.xpi 2>/dev/null | awk '{print "   " $NF " (" $5 ")"}'
echo ""
echo " Update endpoints:"
echo "   Chrome : ${BOOTSTRAP_URL}/updates/mirai-browser.xml"
echo "   Firefox: ${BOOTSTRAP_URL}/updates/mirai-browser.json"
echo ""
echo " Download URLs:"
echo "   CRX: ${BOOTSTRAP_URL}/releases/${SLUG}-${VERSION}.crx"
echo "   XPI: ${BOOTSTRAP_URL}/releases/${SLUG}-${VERSION}.xpi"
echo ""
echo " Auto-update: navigateurs verifient periodiquement"
echo "   Chrome  ~5h  | Firefox ~24h"
echo "========================================="

# Cleanup
rm -rf "$BUILD_DIR"
echo "Done."
