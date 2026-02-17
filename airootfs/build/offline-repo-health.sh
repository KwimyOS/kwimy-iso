#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ISO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_DIR="${1:-$ISO_DIR/airootfs/opt/kwimy-repo}"
LIST_PATH="${2:-$SCRIPT_DIR/offline-packages.txt}"

if [[ ! -d "$REPO_DIR" ]]; then
  echo "Offline repo not found: $REPO_DIR" >&2
  exit 1
fi

if [[ ! -f "$LIST_PATH" ]]; then
  echo "Package list not found: $LIST_PATH" >&2
  exit 1
fi

mapfile -t packages < <(awk 'NF && $1 !~ /^#/ {print $1}' "$LIST_PATH")

if [[ ${#packages[@]} -eq 0 ]]; then
  echo "No packages found in $LIST_PATH" >&2
  exit 1
fi

missing=()
for pkg in "${packages[@]}"; do
  if [[ "$pkg" == "base" ]]; then
    continue
  fi
  if ! ls "$REPO_DIR/$pkg"-*.pkg.tar.zst >/dev/null 2>&1; then
    missing+=("$pkg")
  fi
done

if command -v pacman >/dev/null 2>&1; then
  tmp_conf="$(mktemp)"
  trap 'rm -f "$tmp_conf"' EXIT
  cat >"$tmp_conf" <<EOF
[options]
Architecture = auto
SigLevel = Optional TrustAll
LocalFileSigLevel = Optional

[kwimy-offline]
SigLevel = Optional TrustAll
Server = file://$REPO_DIR
EOF
  if ! pacman --config "$tmp_conf" -Sg base >/dev/null 2>&1; then
    echo "Warning: base group not found in offline repo database." >&2
  fi
fi

if [[ ${#missing[@]} -eq 0 ]]; then
  echo "Offline repo health: OK"
  exit 0
fi

echo "Offline repo missing ${#missing[@]} packages:"
printf '%s\n' "${missing[@]}"
exit 2
