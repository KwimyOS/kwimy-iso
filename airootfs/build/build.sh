#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../../.." && pwd)
INSTALLER_DIR="$ROOT_DIR/kwimy-installer-tui"
ISO_DIR="$ROOT_DIR/kwimy-iso"
ISO_WORK="$ISO_DIR/work"
ISO_OUT="$ISO_DIR/out"
ISO_COPY_DIR="${ISO_COPY_DIR:-}"
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/build-$(date +%Y%m%d-%H%M%S).log"

ENV_FILE="$ROOT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

mkdir -p "$LOG_DIR"
ln -sfn "$LOG_FILE" "$LOG_DIR/build.log"
exec > >(tee "$LOG_FILE") 2>&1

logs_to_delete=$(ls -1t "$LOG_DIR"/build-*.log 2>/dev/null | tail -n +31 || true)
if [ -n "$logs_to_delete" ]; then
  echo "$logs_to_delete" | xargs rm -f
fi

# Get the package name and version from Cargo.toml using awk for safety
PKG_NAME=$(awk -F '"' '/^name/ {print $2; exit}' "$INSTALLER_DIR/Cargo.toml")
PKG_VERSION=$(awk -F '"' '/^version/ {print $2; exit}' "$INSTALLER_DIR/Cargo.toml")

echo "Cleaning ISO work/output directories..."
rm -rf "$ISO_WORK" "$ISO_OUT"

echo "Building ${PKG_NAME} v${PKG_VERSION}..."
echo "Removing old versioned binaries..."
rm -f "$INSTALLER_DIR/target/release/${PKG_NAME}-v"*
rm -f "$ROOT_DIR/${PKG_NAME}-v"*
if [[ -n "${KWIMY_BUILD_JOBS:-}" ]]; then
  cargo build --release -j "$KWIMY_BUILD_JOBS" --manifest-path "$INSTALLER_DIR/Cargo.toml"
else
  cargo build --release --manifest-path "$INSTALLER_DIR/Cargo.toml"
fi

SOURCE_BIN="$INSTALLER_DIR/target/release/${PKG_NAME}"
VERSIONED_NAME="${PKG_NAME}-v${PKG_VERSION}"
DEST_BIN="$INSTALLER_DIR/target/release/${VERSIONED_NAME}"

if [ -f "${SOURCE_BIN}" ]; then
    echo "Copying binary to ${VERSIONED_NAME}..."
    cp -f "${SOURCE_BIN}" "${DEST_BIN}"
else
    echo "Error: Build failed, could not find binary."
    exit 1
fi

echo ""
echo "Build complete!"
echo "Binary available at: ${DEST_BIN}"

echo ""
echo "Building ISO..."
"$ISO_DIR/build-iso.sh"

ISO_PATH=$(ls -t "$ISO_OUT"/kwimy-*.iso 2>/dev/null | head -n 1 || true)
if [ -z "$ISO_PATH" ]; then
    echo "Error: ISO not found in $ISO_OUT"
    exit 1
fi

if [ -n "$ISO_COPY_DIR" ]; then
    mkdir -p "$ISO_COPY_DIR"
    cp -f "$ISO_PATH" "$ISO_COPY_DIR/"
    echo "Copied ISO to: $ISO_COPY_DIR"
fi

echo ""
echo "Creating VM..."
echo "Using ISO: $ISO_PATH"
ISO_PATH="$ISO_PATH" "$ROOT_DIR/kwimy-iso/airootfs/build/create-vm.sh"
