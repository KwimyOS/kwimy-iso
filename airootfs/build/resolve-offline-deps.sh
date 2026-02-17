#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage:"
  echo "  $0 [input_list] [output_list]"
  echo ""
  echo "Env:"
  echo "  RESOLVE_MIRROR_URL=https://mirror.kwimy.com/stable"
  echo "  RESOLVE_SKIP_SYNC=1"
  echo "  ALLOW_MISSING_PATH=/path/to/allow-missing.txt"
  exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
INPUT_PATH="${1:-$SCRIPT_DIR/offline-packages.txt}"
OUTPUT_PATH="${2:-$SCRIPT_DIR/offline-packages.resolved.txt}"
ALLOW_MISSING_PATH="${ALLOW_MISSING_PATH:-$SCRIPT_DIR/offline-packages.allow-missing.txt}"
RESOLVE_MIRROR_URL="${RESOLVE_MIRROR_URL:-}"

PACMAN_CONF_OVERRIDE=""
PACMAN_DBPATH_OVERRIDE=""
TMP_DIR=""
TMP_LIST=""
cleanup() {
  if [[ -n "$TMP_LIST" ]]; then
    rm -f "$TMP_LIST"
  fi
  if [[ -n "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

if [[ -n "$RESOLVE_MIRROR_URL" ]]; then
  TMP_DIR="$(mktemp -d)"
  PACMAN_DBPATH_OVERRIDE="$TMP_DIR/db"
  mkdir -p "$PACMAN_DBPATH_OVERRIDE" "$TMP_DIR/cache"

  MIRRORLIST_PATH="$TMP_DIR/mirrorlist-kwimy"
  echo "Server = ${RESOLVE_MIRROR_URL%/}/\$repo/os/\$arch" >"$MIRRORLIST_PATH"

  PACMAN_CONF_OVERRIDE="$TMP_DIR/pacman.conf"
  cat >"$PACMAN_CONF_OVERRIDE" <<EOF
[options]
Architecture = auto
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional
CacheDir = $TMP_DIR/cache
DBPath = $PACMAN_DBPATH_OVERRIDE

[core]
Include = $MIRRORLIST_PATH

[extra]
Include = $MIRRORLIST_PATH

[multilib]
Include = $MIRRORLIST_PATH
EOF
fi

if ! command -v pactree >/dev/null 2>&1; then
  echo "pactree not found (install pacman-contrib)." >&2
  exit 1
fi

if [[ -z "${RESOLVE_SKIP_SYNC:-}" ]]; then
  if command -v pacman >/dev/null 2>&1; then
    if [[ -n "$PACMAN_CONF_OVERRIDE" ]]; then
      if ! pacman -Sy --noconfirm --config "$PACMAN_CONF_OVERRIDE" --dbpath "$PACMAN_DBPATH_OVERRIDE" >/dev/null; then
        echo "Failed to sync pacman databases using RESOLVE_MIRROR_URL." >&2
        exit 1
      fi
    elif ! pacman -Sy --noconfirm >/dev/null; then
      echo "Failed to sync pacman databases. Set RESOLVE_SKIP_SYNC=1 to skip." >&2
      exit 1
    fi
  else
    echo "pacman not found; cannot sync databases." >&2
    exit 1
  fi
fi

if [[ ! -f "$INPUT_PATH" ]]; then
  echo "Input file not found: $INPUT_PATH" >&2
  exit 1
fi

mapfile -t seed_packages < <(awk 'NF && $1 !~ /^#/ {print $1}' "$INPUT_PATH")
allow_missing=()
if [[ -f "$ALLOW_MISSING_PATH" ]]; then
  mapfile -t allow_missing < <(awk 'NF && $1 !~ /^#/ {print $1}' "$ALLOW_MISSING_PATH")
fi

if [[ ${#seed_packages[@]} -eq 0 ]]; then
  echo "No packages found in $INPUT_PATH" >&2
  exit 1
fi

TMP_LIST="$(mktemp)"
tmp_list="$TMP_LIST"

failed=()
for pkg in "${seed_packages[@]}"; do
  if [[ -n "$PACMAN_CONF_OVERRIDE" ]]; then
    if ! pactree -u -l -s --sync --config "$PACMAN_CONF_OVERRIDE" --dbpath "$PACMAN_DBPATH_OVERRIDE" "$pkg" >>"$tmp_list" 2>/dev/null; then
      if printf '%s\n' "${allow_missing[@]}" | grep -qxF "$pkg"; then
        echo "Skipping dep resolution for allowlisted package: $pkg" >&2
      else
        echo "Failed to resolve deps for $pkg" >&2
        failed+=("$pkg")
      fi
      echo "$pkg" >>"$tmp_list"
    fi
    continue
  fi
  if ! pactree -u -l -s "$pkg" >>"$tmp_list" 2>/dev/null; then
    if printf '%s\n' "${allow_missing[@]}" | grep -qxF "$pkg"; then
      echo "Skipping dep resolution for allowlisted package: $pkg" >&2
    else
      echo "Failed to resolve deps for $pkg" >&2
      failed+=("$pkg")
    fi
    echo "$pkg" >>"$tmp_list"
  fi
done

sort -u "$tmp_list" >"$OUTPUT_PATH"
if [[ ${#failed[@]} -gt 0 ]]; then
  echo "Failed to resolve dependencies for: ${failed[*]}" >&2
  echo "Add custom packages to $ALLOW_MISSING_PATH or run without RESOLVE_SKIP_SYNC." >&2
  exit 1
fi
echo "Wrote resolved package list to $OUTPUT_PATH"
