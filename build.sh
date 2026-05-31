#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

PASSWORD="${1:-${STATICRYPT_PASSWORD:-akidon}}"
SRC_DIR="src"
BUILD_DIR=".build"
BUNDLE_FILE="$BUILD_DIR/index.html"
OUT_FILE="index.html"

mkdir -p "$BUILD_DIR"

# 1. Inline styles.css and app.js into one HTML file (named index.html so the encrypted output keeps the name)
python3 <<PYEOF > "$BUNDLE_FILE"
html = open("$SRC_DIR/index.html").read()
css = open("$SRC_DIR/styles.css").read()
js = open("$SRC_DIR/app.js").read()

html = html.replace(
    '<link rel="stylesheet" href="styles.css">',
    f'<style>\n{css}\n</style>'
)
html = html.replace(
    '<script src="app.js"></script>',
    f'<script>\n{js}\n</script>'
)
print(html, end='')
PYEOF

# 2. Encrypt with StatiCrypt; staticrypt writes to <output-dir>/<input-basename>
rm -rf "$BUILD_DIR/encrypted"
npx -y staticrypt "$BUNDLE_FILE" \
  -p "$PASSWORD" \
  --short \
  -d "$BUILD_DIR/encrypted" >/dev/null

cp "$BUILD_DIR/encrypted/index.html" "$OUT_FILE"

# 3. Inject noindex meta tag into encrypted output
python3 <<PYEOF
html = open("$OUT_FILE").read()
needle = '<meta name="viewport" content="width=device-width, initial-scale=1" />'
if 'name="robots"' not in html and needle in html:
    html = html.replace(
        needle,
        needle + '\n        <meta name="robots" content="noindex, nofollow, noarchive, nosnippet" />'
    )
    open("$OUT_FILE", "w").write(html)
PYEOF

echo "Built $OUT_FILE (password: $PASSWORD)"
