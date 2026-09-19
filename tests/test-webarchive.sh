#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CASE="$TMP/case"
mkdir -p "$CASE" "$TMP/bin"
cat > "$TMP/page.html" <<'HTML'
url: https://example.test/source
observedAt(UTC): 2026-09-19T00:00:00Z
<html><body>evidence</body></html>
HTML
cat > "$TMP/bin/stamp" <<'SH'
#!/bin/sh
set -eu
touch "$1.test-stamped"
SH
chmod +x "$TMP/bin/stamp"

SHA="$(shasum -a 256 "$TMP/page.html" | awk '{print $1}')"
SHORT="${SHA:0:12}"
export LIUZHENG_STAMP_BIN="$TMP/bin/stamp"
export LIUZHENG_NOW_UTC="20260919T000000Z"

"$ROOT/bin/webarchive" "$TMP/page.html" "$CASE" "test capture" >/dev/null
ARCHIVE="$CASE/_证据/webarchive/20260919T000000Z__${SHORT}__page.html"
test -f "$ARCHIVE"
test -f "$ARCHIVE.test-stamped"
test "$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')" = "$SHA"
test "$(wc -l < "$CASE/_证据/anchors.jsonl" | tr -d ' ')" = 1
grep -q "$SHA" "$CASE/_证据/anchors.jsonl"
grep -q 'https://example.test/source' "$CASE/_证据/anchors.jsonl"

if "$ROOT/bin/webarchive" "$TMP/page.html" "$CASE" "duplicate" >/dev/null 2>&1; then
  echo "expected duplicate archive to fail closed" >&2
  exit 1
fi
test "$(wc -l < "$CASE/_证据/anchors.jsonl" | tr -d ' ')" = 1

echo "PASS webarchive immutable archive"
