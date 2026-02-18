#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
INSTALLER_DIR="$ROOT_DIR/kwimy-installer-tui"
ISO_DIR="$ROOT_DIR/kwimy-iso"
BIN_SRC="$INSTALLER_DIR/target/release/kwimy"
BIN_DEST="$ISO_DIR/airootfs/usr/bin/kwimy-installer"
SDDM_THEME_SRC="$ROOT_DIR/kwimy-pkgs/pkgs/kwimy-pixie-sddm"
SDDM_THEME_DEST="$ISO_DIR/airootfs/usr/share/sddm/themes/kwimy-pixie-sddm"
PLYMOUTH_LUKS_SRC="$ROOT_DIR/kwimy-pkgs/pkgs/kwimy-luks"
PLYMOUTH_LUKS_DEST="$ISO_DIR/airootfs/usr/share/plymouth/themes/kwimy-luks"
PLYMOUTH_SPLASH_SRC="$ROOT_DIR/kwimy-pkgs/pkgs/kwimy-splash"
PLYMOUTH_SPLASH_DEST="$ISO_DIR/airootfs/usr/share/plymouth/themes/kwimy-splash"
GRUB_THEME_SRC="$ROOT_DIR/kwimy-pkgs/pkgs/kwimy-vimix-grub/theme"
GRUB_THEME_DEST="$ISO_DIR/grub/themes/kwimy-vimix-grub"
GRUB_THEME_DEST_ROOTFS="$ISO_DIR/airootfs/usr/share/grub/themes/kwimy-vimix-grub"
LOCAL_PKG_BUILDER="$ROOT_DIR/kwimy-pkgs/build-local.sh"
KWIMY_GPG_SRC="$ROOT_DIR/kwimy-repo.gpg"
KWIMY_GPG_DEST="$ISO_DIR/airootfs/usr/share/kwimy/kwimy-repo.gpg"
VERSION_FILE="$ISO_DIR/VERSION"
OS_RELEASE_PATH="$ISO_DIR/airootfs/etc/os-release"
OFFLINE_LIST="$ISO_DIR/airootfs/build/offline-packages.txt"
OFFLINE_RESOLVED="$ISO_DIR/airootfs/build/offline-packages.resolved.txt"
OFFLINE_REPO="$ISO_DIR/airootfs/opt/kwimy-repo"
OFFLINE_LOCAL="$ISO_DIR/offline-local"
OFFLINE_EXCLUDE=""
KWIMY_GPG_SRC_OFFLINE="$OFFLINE_REPO/kwimy-repo.gpg"
PACMAN_OFFLINE_CONF="$(mktemp)"
PACMAN_CONF_PATH="$ISO_DIR/pacman.conf"
PACMAN_CONF_BACKUP=""
MIRRORLIST_KWIMY="/etc/pacman.d/mirrorlist-kwimy"
ISO_MIRRORLIST_KWIMY="$ISO_DIR/airootfs/etc/pacman.d/mirrorlist-kwimy"
OWNER_USER="${SUDO_USER:-$(id -un)}"
OWNER_GROUP="$(id -gn "$OWNER_USER" 2>/dev/null || echo "$OWNER_USER")"
ENV_FILE="$ROOT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

if [[ -f "$VERSION_FILE" ]]; then
  VERSION=$(head -n 1 "$VERSION_FILE" | tr -d '[:space:]')
else
  echo "Error: Missing ISO version file at $VERSION_FILE" >&2
  exit 1
fi

if [[ -z "$VERSION" ]]; then
  echo "Error: ISO version file is empty: $VERSION_FILE" >&2
  exit 1
fi

cleanup() {
  rm -f "$PACMAN_OFFLINE_CONF"
  if [[ -n "$OFFLINE_EXCLUDE" ]]; then
    rm -f "$OFFLINE_EXCLUDE"
  fi
  if [[ -n "$PACMAN_CONF_BACKUP" && -f "$PACMAN_CONF_BACKUP" ]]; then
    mv -f "$PACMAN_CONF_BACKUP" "$PACMAN_CONF_PATH"
  fi
  if [[ -f "$PACMAN_CONF_PATH" ]]; then
    chown "$OWNER_USER:$OWNER_GROUP" "$PACMAN_CONF_PATH" || true
  fi
}
trap cleanup EXIT

if [[ -n "${KWIMY_BUILD_JOBS:-}" ]]; then
  cargo build --release -j "$KWIMY_BUILD_JOBS" --manifest-path "$INSTALLER_DIR/Cargo.toml"
else
  cargo build --release --manifest-path "$INSTALLER_DIR/Cargo.toml"
fi

if [[ "${KWIMY_SKIP_LOCAL_PKG_BUILD:-0}" != "1" && -x "$LOCAL_PKG_BUILDER" ]]; then
  "$LOCAL_PKG_BUILDER" kwimy-vimix-grub || \
    echo "Warning: Failed to build local kwimy-vimix-grub package." >&2
  "$LOCAL_PKG_BUILDER" kwimy-luks || \
    echo "Warning: Failed to build local kwimy-luks package." >&2
  "$LOCAL_PKG_BUILDER" kwimy-splash || \
    echo "Warning: Failed to build local kwimy-splash package." >&2
  "$LOCAL_PKG_BUILDER" kwimy-lazyvim || \
    echo "Warning: Failed to build local kwimy-lazyvim package." >&2
fi
install -Dm755 "$BIN_SRC" "$BIN_DEST"
mkdir -p "$(dirname "$KWIMY_GPG_DEST")"
if [[ -f "$KWIMY_GPG_SRC" ]]; then
  install -Dm644 "$KWIMY_GPG_SRC" "$KWIMY_GPG_DEST"
elif [[ -f "$KWIMY_GPG_SRC_OFFLINE" ]]; then
  install -Dm644 "$KWIMY_GPG_SRC_OFFLINE" "$KWIMY_GPG_DEST"
elif command -v curl >/dev/null 2>&1; then
  if ! curl -fsSL https://pkgs.kwimy.com/kwimy-repo.gpg -o "$KWIMY_GPG_DEST"; then
    echo "Warning: Failed to download kwimy-repo.gpg key." >&2
    rm -f "$KWIMY_GPG_DEST"
  fi
else
  echo "Warning: curl not found; skipping kwimy-repo.gpg key download." >&2
fi
if [[ -d "$SDDM_THEME_SRC" ]]; then
  mkdir -p "$(dirname "$SDDM_THEME_DEST")"
  rm -rf "$SDDM_THEME_DEST"
  cp -a "$SDDM_THEME_SRC" "$SDDM_THEME_DEST"
else
  echo "Warning: SDDM theme not found at $SDDM_THEME_SRC" >&2
fi

if [[ -d "$PLYMOUTH_LUKS_SRC" ]]; then
  mkdir -p "$(dirname "$PLYMOUTH_LUKS_DEST")"
  rm -rf "$PLYMOUTH_LUKS_DEST"
  cp -a "$PLYMOUTH_LUKS_SRC" "$PLYMOUTH_LUKS_DEST"
else
  echo "Warning: Plymouth LUKS theme not found at $PLYMOUTH_LUKS_SRC" >&2
fi

if [[ -d "$PLYMOUTH_SPLASH_SRC" ]]; then
  mkdir -p "$(dirname "$PLYMOUTH_SPLASH_DEST")"
  rm -rf "$PLYMOUTH_SPLASH_DEST"
  cp -a "$PLYMOUTH_SPLASH_SRC" "$PLYMOUTH_SPLASH_DEST"
else
  echo "Warning: Plymouth splash theme not found at $PLYMOUTH_SPLASH_SRC" >&2
fi

if [[ -d "$GRUB_THEME_SRC" ]]; then
  mkdir -p "$(dirname "$GRUB_THEME_DEST")"
  rm -rf "$GRUB_THEME_DEST"
  cp -a "$GRUB_THEME_SRC" "$GRUB_THEME_DEST"

  mkdir -p "$(dirname "$GRUB_THEME_DEST_ROOTFS")"
  rm -rf "$GRUB_THEME_DEST_ROOTFS"
  cp -a "$GRUB_THEME_SRC" "$GRUB_THEME_DEST_ROOTFS"
else
  echo "Warning: GRUB theme not found at $GRUB_THEME_SRC" >&2
fi

if [[ -f "$MIRRORLIST_KWIMY" ]]; then
  mkdir -p "$(dirname "$ISO_MIRRORLIST_KWIMY")"
  cp -f "$MIRRORLIST_KWIMY" "$ISO_MIRRORLIST_KWIMY"
else
  echo "Warning: $MIRRORLIST_KWIMY not found; falling back to default mirrorlist." >&2
fi

mkdir -p "$ISO_DIR/airootfs/etc"
cat > "$OS_RELEASE_PATH" <<EOF
NAME=Kwimy
PRETTY_NAME="Kwimy"
ID=kwimy
ID_LIKE=arch
VERSION_ID=${VERSION}
VERSION="${VERSION}"
EOF

WORK_DIR="$ISO_DIR/work"
OUT_DIR="$ISO_DIR/out"

rm -rf "$WORK_DIR" "$OUT_DIR"

if [[ -f "$OFFLINE_RESOLVED" ]]; then
  OFFLINE_LIST="$OFFLINE_RESOLVED"
fi

if [[ "${KWIMY_SKIP_OFFLINE_REPO:-0}" == "1" ]]; then
  echo "Skipping offline repo build (KWIMY_SKIP_OFFLINE_REPO=1)"
elif [[ -f "$OFFLINE_LIST" ]] || [[ -d "$OFFLINE_LOCAL" ]]; then
  mkdir -p "$OFFLINE_REPO"
  if [[ -f "$OFFLINE_LIST" ]]; then
    mapfile -t OFFLINE_PACKAGES < <(grep -Ev '^[[:space:]]*(#|$)' "$OFFLINE_LIST")
  else
    OFFLINE_PACKAGES=()
  fi
  if [[ ${#OFFLINE_PACKAGES[@]} -gt 0 ]]; then
    cat > "$PACMAN_OFFLINE_CONF" <<'EOF'
[options]
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional
ParallelDownloads = 5
Architecture = auto

[core]
Include = /etc/pacman.d/mirrorlist-kwimy

[extra]
Include = /etc/pacman.d/mirrorlist-kwimy

[multilib]
Include = /etc/pacman.d/mirrorlist-kwimy

[kwimy]
SigLevel = Required DatabaseOptional
Server = https://pkgs.kwimy.com/stable/$arch
EOF
    if [[ -f "$PACMAN_CONF_PATH" ]]; then
      PACMAN_CONF_BACKUP="$(mktemp)"
      cp -f "$PACMAN_CONF_PATH" "$PACMAN_CONF_BACKUP"
      sed -i "s|file:///opt/kwimy-repo|file://$OFFLINE_REPO|g" "$PACMAN_CONF_PATH"
    fi
  fi

  if [[ -d "$OFFLINE_LOCAL" ]]; then
    shopt -s nullglob
    OFFLINE_EXCLUDE="$(mktemp)"
    for pkg in "$OFFLINE_LOCAL"/*.pkg.tar.zst; do
      if command -v bsdtar >/dev/null 2>&1; then
        bsdtar -xf "$pkg" -O .PKGINFO 2>/dev/null | awk -F ' = ' '/^pkgname = / {print $2; exit}' \
          >> "$OFFLINE_EXCLUDE" || true
      fi
    done
    for pkg in "$OFFLINE_LOCAL"/*.pkg.tar.zst; do
      cp -f "$pkg" "$OFFLINE_REPO/"
    done
    shopt -u nullglob
  fi

  if [[ ${#OFFLINE_PACKAGES[@]} -gt 0 ]]; then
    if [[ -n "$OFFLINE_EXCLUDE" && -s "$OFFLINE_EXCLUDE" ]]; then
      mapfile -t OFFLINE_PACKAGES < <(printf '%s\n' "${OFFLINE_PACKAGES[@]}" | grep -vxFf "$OFFLINE_EXCLUDE")
    fi
    if [[ ${#OFFLINE_PACKAGES[@]} -gt 0 ]]; then
      pacman -Syw --noconfirm --cachedir "$OFFLINE_REPO" --config "$PACMAN_OFFLINE_CONF" \
        "${OFFLINE_PACKAGES[@]}"
    fi
  fi

  if compgen -G "$OFFLINE_REPO/*.pkg.tar.zst" > /dev/null; then
    repo-add "$OFFLINE_REPO/kwimy-offline.db.tar.gz" "$OFFLINE_REPO"/*.pkg.tar.zst
    if ! compgen -G "$OFFLINE_REPO/linux-firmware-*.pkg.tar.zst" > /dev/null; then
      echo "Warning: linux-firmware not found in offline repo." >&2
    fi
  fi
fi

if [[ -n "${KWIMY_BUILD_JOBS:-}" ]]; then
  export KWIMY_BUILD_JOBS
  export XZ_OPT="--threads=${KWIMY_BUILD_JOBS}"
  export ZSTD_NBTHREADS="${KWIMY_BUILD_JOBS}"
  echo "Exporting KWIMY_BUILD_JOBS=${KWIMY_BUILD_JOBS} for mkarchiso"
  echo "Exporting XZ_OPT=${XZ_OPT}"
  echo "Exporting ZSTD_NBTHREADS=${ZSTD_NBTHREADS}"
fi

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$ISO_DIR"

if [[ -f "$PACMAN_CONF_PATH" ]]; then
  chown "$OWNER_USER:$OWNER_GROUP" "$PACMAN_CONF_PATH"
fi

rm -rf "$GRUB_THEME_DEST" "$GRUB_THEME_DEST_ROOTFS"
rm -rf "$SDDM_THEME_DEST"
rm -rf "$PLYMOUTH_LUKS_DEST" "$PLYMOUTH_SPLASH_DEST"
