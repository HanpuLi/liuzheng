#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="${LIUZHENG_BIN_DIR:-$HOME/bin}"
INSTALL_SKILLS=0
SKILLS_DIR="${LIUZHENG_SKILLS_DIR:-$HOME/.claude/skills}"
FORCE=0
TOOLS=(gmail-eml stamp webarchive ots-upgrade-sweep.sh)
SKILLS=(duiwai-goutong luodang)

usage() {
  cat <<'EOF'
Usage: ./scripts/install.sh [options]

Options:
  --bin-dir DIR            Install the four CLI tools into DIR (default: ~/bin)
  --with-claude-skills     Also install the two skills
  --skills-dir DIR         Skills destination (default: ~/.claude/skills);
                           implies --with-claude-skills
  --force                  Back up and replace conflicting existing files
  -h, --help               Show this help

The installer is offline and fail-closed: it preflights every destination before
writing anything. Existing different files/directories cause an error unless
--force is supplied.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bin-dir)
      [ "$#" -ge 2 ] || { echo "missing value for --bin-dir" >&2; exit 2; }
      BIN_DIR="$2"; shift 2 ;;
    --with-claude-skills)
      INSTALL_SKILLS=1; shift ;;
    --skills-dir)
      [ "$#" -ge 2 ] || { echo "missing value for --skills-dir" >&2; exit 2; }
      INSTALL_SKILLS=1; SKILLS_DIR="$2"; shift 2 ;;
    --force)
      FORCE=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2 ;;
  esac
done

timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
conflicts=0

same_file() {
  [ -f "$1" ] && [ ! -L "$1" ] && cmp -s "$1" "$2"
}

same_dir() {
  [ -d "$1" ] && [ ! -L "$1" ] && diff -qr "$1" "$2" >/dev/null 2>&1
}

next_backup_path() {
  local src="$1" base candidate n
  base="$src.bak.$timestamp"
  candidate="$base"
  n=1
  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    candidate="$base.$n"
    n=$((n + 1))
  done
  printf '%s\n' "$candidate"
}

backup_existing() {
  local src="$1" backup="$2"
  if [ -L "$src" ]; then
    cp -P "$src" "$backup"
  elif [ -d "$src" ]; then
    cp -Rp "$src" "$backup"
  else
    cp -p "$src" "$backup"
  fi
}

echo "liuzheng install preflight"
echo "  CLI:    $BIN_DIR"
if [ -e "$BIN_DIR" ] && [ ! -d "$BIN_DIR" ]; then
  echo "CLI destination is not a directory: $BIN_DIR" >&2
  exit 2
fi
if [ "$INSTALL_SKILLS" -eq 1 ]; then
  echo "  skills: $SKILLS_DIR"
  if [ -e "$SKILLS_DIR" ] && [ ! -d "$SKILLS_DIR" ]; then
    echo "skills destination is not a directory: $SKILLS_DIR" >&2
    exit 2
  fi
fi

for name in "${TOOLS[@]}"; do
  src="$ROOT/bin/$name"
  dst="$BIN_DIR/$name"
  [ -f "$src" ] || { echo "missing source tool: $src" >&2; exit 1; }
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if same_file "$dst" "$src"; then
      :
    elif [ "$FORCE" -eq 0 ]; then
      echo "conflict: $dst already exists and differs" >&2
      conflicts=1
    fi
  fi
done

if [ "$INSTALL_SKILLS" -eq 1 ]; then
  for name in "${SKILLS[@]}"; do
    src="$ROOT/skills/$name"
    dst="$SKILLS_DIR/$name"
    [ -d "$src" ] || { echo "missing source skill: $src" >&2; exit 1; }
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      if same_dir "$dst" "$src"; then
        :
      elif [ "$FORCE" -eq 0 ]; then
        echo "conflict: $dst already exists and differs" >&2
        conflicts=1
      fi
    fi
  done
fi

if [ "$conflicts" -ne 0 ]; then
  echo "nothing installed; resolve conflicts or re-run with --force" >&2
  exit 3
fi

mkdir -p "$BIN_DIR"
for name in "${TOOLS[@]}"; do
  src="$ROOT/bin/$name"
  dst="$BIN_DIR/$name"
  if same_file "$dst" "$src"; then
    chmod 0755 "$dst" 2>/dev/null || true
    echo "up to date: $dst"
    continue
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    backup="$(next_backup_path "$dst")"
    backup_existing "$dst" "$backup"
    rm -rf -- "$dst"
    echo "backup: $backup"
  fi

  tmp="$(mktemp "$BIN_DIR/.liuzheng-$name.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  install -m 0755 "$src" "$tmp"
  mv -f "$tmp" "$dst"
  trap - EXIT
  echo "installed: $dst"
done

if [ "$INSTALL_SKILLS" -eq 1 ]; then
  mkdir -p "$SKILLS_DIR"
  for name in "${SKILLS[@]}"; do
    src="$ROOT/skills/$name"
    dst="$SKILLS_DIR/$name"
    if same_dir "$dst" "$src"; then
      echo "up to date: $dst"
      continue
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
      backup="$(next_backup_path "$dst")"
      backup_existing "$dst" "$backup"
      rm -rf -- "$dst"
      echo "backup: $backup"
    fi

    tmpdir="$(mktemp -d "$SKILLS_DIR/.liuzheng-$name.XXXXXX")"
    trap 'rm -rf "$tmpdir"' EXIT
    cp -Rp "$src/." "$tmpdir/"
    mv "$tmpdir" "$dst"
    trap - EXIT
    echo "installed: $dst"
  done
fi

echo
echo "Installation complete."
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "note: $BIN_DIR is not currently on PATH" ;;
esac
echo "Run 'gmail-eml --help' and read docs/install.md before using evidence tools."
