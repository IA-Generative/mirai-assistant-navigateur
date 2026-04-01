#!/usr/bin/env bash
# build.sh — Compile le plugin Chrome/Firefox avec les fichiers DM
# Usage:
#   scripts/build.sh                    → build dans dist/
#   scripts/build.sh --crx              → + genere le .crx signe
#   scripts/build.sh --xpi              → + genere le .xpi
#   scripts/build.sh --crx --xpi        → les deux

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
EXT_DIR="$DIST_DIR/extension"
VERSION=$(python3 -c "import json; print(json.load(open('$ROOT_DIR/manifest.json'))['version'])")

echo "Building MirAI Recorder v$VERSION..."
echo ""

# ──────────────────────────────────────────────
# 1. Clean
# ──────────────────────────────────────────────
rm -rf "$DIST_DIR"
mkdir -p "$EXT_DIR"

# ──────────────────────────────────────────────
# 2. Copy extension files
# ──────────────────────────────────────────────
# Manifest (racine — requis par Chrome)
cp "$ROOT_DIR/manifest.json" "$EXT_DIR/"
cp "$ROOT_DIR/package.json" "$EXT_DIR/"

# Source (tout src/)
cp -r "$ROOT_DIR/src/" "$EXT_DIR/src/"

# Icons
cp -r "$ROOT_DIR/icons/" "$EXT_DIR/icons/"

# DM files at ZIP root (required by Device Management)
# DM auto-detects and strips them from the distributed binary
cp "$ROOT_DIR/src/dm/manifest.json" "$EXT_DIR/dm-manifest.json"
cp "$ROOT_DIR/src/dm/config.json" "$EXT_DIR/dm-config.json"

# ──────────────────────────────────────────────
# 3. Verification
# ──────────────────────────────────────────────
echo "Fichiers dans dist/extension/ :"
find "$EXT_DIR" -type f | sed "s|$EXT_DIR/||" | sort | while read f; do
  echo "  $f"
done

FILE_COUNT=$(find "$EXT_DIR" -type f | wc -l | tr -d ' ')
echo ""
echo "$FILE_COUNT fichiers prets."

# Verifier les references du manifest
python3 -c "
import json, os, sys
os.chdir('$EXT_DIR')
m = json.load(open('manifest.json'))
errors = []
for f in [m['background']['service_worker'], m['action']['default_popup'], m['options_ui']['page']]:
    if not os.path.isfile(f): errors.append(f)
for s, p in m['icons'].items():
    if not os.path.isfile(p): errors.append(p)
if errors:
    print('ERREUR — fichiers manquants :', errors)
    sys.exit(1)
print('Manifest OK — toutes les references existent.')
"

# ──────────────────────────────────────────────
# 4. CRX (optionnel)
# ──────────────────────────────────────────────
if [[ " $* " == *" --crx "* ]]; then
  PEM_KEY="$ROOT_DIR/private/mirai-browser-key.pem"
  if [ ! -f "$PEM_KEY" ]; then
    echo "ERREUR: Cle PEM non trouvee ($PEM_KEY)"
    exit 1
  fi

  CHROME_BIN=""
  for candidate in \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "$(which chromium 2>/dev/null || true)" \
    "$(which google-chrome 2>/dev/null || true)"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      CHROME_BIN="$candidate"
      break
    fi
  done

  if [ -z "$CHROME_BIN" ]; then
    echo "ERREUR: Chrome/Chromium non trouve"
    exit 1
  fi

  echo ""
  echo "Packaging CRX..."
  "$CHROME_BIN" --pack-extension="$EXT_DIR" --pack-extension-key="$PEM_KEY" 2>/dev/null || true

  if [ -f "${EXT_DIR}.crx" ]; then
    mv "${EXT_DIR}.crx" "$DIST_DIR/mirai-browser-${VERSION}.crx"
    CRX_SIZE=$(du -h "$DIST_DIR/mirai-browser-${VERSION}.crx" | cut -f1)
    echo "  OK  dist/mirai-browser-${VERSION}.crx ($CRX_SIZE)"
  else
    echo "  ERREUR: CRX non genere"
  fi
fi

# ──────────────────────────────────────────────
# 5. XPI (optionnel)
# ──────────────────────────────────────────────
if [[ " $* " == *" --xpi "* ]]; then
  echo ""
  echo "Packaging XPI..."
  (cd "$EXT_DIR" && zip -r -q "$DIST_DIR/mirai-browser-${VERSION}.xpi" .)
  XPI_SIZE=$(du -h "$DIST_DIR/mirai-browser-${VERSION}.xpi" | cut -f1)
  echo "  OK  dist/mirai-browser-${VERSION}.xpi ($XPI_SIZE)"
fi

# ──────────────────────────────────────────────
# 6. Resume
# ──────────────────────────────────────────────
echo ""
echo "========================================="
echo " Build MirAI Recorder v$VERSION"
echo "========================================="
echo " dist/extension/                  → extension non empaquetee"
echo "                                    (chargeable dans chrome://extensions)"
[ -f "$DIST_DIR/mirai-browser-${VERSION}.crx" ] && echo " dist/mirai-browser-${VERSION}.crx → Chrome signe"
[ -f "$DIST_DIR/mirai-browser-${VERSION}.xpi" ] && echo " dist/mirai-browser-${VERSION}.xpi → Firefox"
echo ""
echo " Contenu DM inclus :"
echo "   src/dm/config.json   → config multi-profils"
echo "   src/dm/manifest.json → metadata DM"
echo "   src/dm/bootstrap.js  → client config DM"
echo "   src/dm/telemetry.js  → telemetrie OTLP"
echo "   src/auth.js          → PKCE + enrollment DM"
echo "========================================="
