#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/fake-bin"
printf 'evidence\n' > "$TMP/evidence.txt"

cat > "$TMP/fake-bin/curl" <<'SH'
#!/bin/sh
set -eu
out=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then
    shift
    out="$1"
  fi
  shift
done
[ -n "$out" ]
printf 'HTTP 200 but not an RFC3161 response\n' > "$out"
SH
chmod +x "$TMP/fake-bin/curl"

if PATH="$TMP/fake-bin:$PATH" LIUZHENG_OTS_BIN=/nonexistent/ots "$ROOT/bin/stamp" "$TMP/evidence.txt" >"$TMP/out" 2>&1; then
  echo "stamp accepted malformed TSA responses" >&2
  cat "$TMP/out" >&2
  exit 1
fi

grep -q '0/4 个时间戳' "$TMP/out"
test ! -e "$TMP/evidence.txt.freetsa.tsr"
test ! -e "$TMP/evidence.txt.digicert.tsr"
test ! -e "$TMP/evidence.txt.aimoda.tsr"

echo "PASS stamp rejects malformed TSA responses"
