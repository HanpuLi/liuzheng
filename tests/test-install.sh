#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BIN="$TMP/bin"
SKILLS="$TMP/skills"

"$ROOT/scripts/install.sh" --bin-dir "$BIN" --skills-dir "$SKILLS"

for name in gmail-eml stamp webarchive ots-upgrade-sweep.sh; do
  test -x "$BIN/$name"
  cmp -s "$ROOT/bin/$name" "$BIN/$name"
done
for name in duiwai-goutong luodang; do
  test -d "$SKILLS/$name"
  diff -qr "$ROOT/skills/$name" "$SKILLS/$name" >/dev/null
done

# Idempotent repeat should not create backups.
"$ROOT/scripts/install.sh" --bin-dir "$BIN" --skills-dir "$SKILLS" >/dev/null
if find "$TMP" -name '*.bak.*' -print | grep -q .; then
  echo "idempotent install unexpectedly created a backup" >&2
  exit 1
fi

# webarchive must find an adjacent installed stamp even outside ~/bin.
cat > "$BIN/stamp" <<'SH'
#!/bin/sh
set -eu
touch "$1.test-stamped"
SH
chmod +x "$BIN/stamp"
mkdir -p "$TMP/case"
cat > "$TMP/page.html" <<'HTML'
url: https://example.test/installer
observedAt(UTC): 2026-09-19T00:00:00Z
<html><body>installer test</body></html>
HTML
LIUZHENG_NOW_UTC=20260919T000000Z "$BIN/webarchive" "$TMP/page.html" "$TMP/case" "installer sibling stamp" >/dev/null
test -f "$TMP/case/_证据/webarchive/"*.test-stamped

# A conflict must abort before any partial install.
CONFLICT_BIN="$TMP/conflict-bin"
mkdir -p "$CONFLICT_BIN"
printf 'local custom tool\n' > "$CONFLICT_BIN/gmail-eml"
CONFLICT_LOG="$TMP/install-conflict.out"
if "$ROOT/scripts/install.sh" --bin-dir "$CONFLICT_BIN" >"$CONFLICT_LOG" 2>&1; then
  echo "expected conflict install to fail" >&2
  exit 1
fi
test ! -e "$CONFLICT_BIN/stamp"
test ! -e "$CONFLICT_BIN/webarchive"
test ! -e "$CONFLICT_BIN/ots-upgrade-sweep.sh"
grep -q 'nothing installed' "$CONFLICT_LOG"

# --force must preserve the prior conflicting file before replacement.
"$ROOT/scripts/install.sh" --bin-dir "$CONFLICT_BIN" --force >/dev/null
cmp -s "$ROOT/bin/gmail-eml" "$CONFLICT_BIN/gmail-eml"
backup="$(find "$CONFLICT_BIN" -maxdepth 1 -name 'gmail-eml.bak.*' -print | head -1)"
test -n "$backup"
grep -q 'local custom tool' "$backup"

echo "PASS installer fail-closed / idempotent / force-backup"
