#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
INSTALLER_DIR="$ROOT_DIR/kwimy-installer-tui"
ISO_DIR="$ROOT_DIR/kwimy-iso"
BIN_SRC="$INSTALLER_DIR/target/release/kwimy"
BIN_DEST="$ISO_DIR/airootfs/usr/bin/kwimy-installer"

cargo build --release --manifest-path "$INSTALLER_DIR/Cargo.toml"
install -Dm755 "$BIN_SRC" "$BIN_DEST"

echo "Updated live ISO binary at: $BIN_DEST"
