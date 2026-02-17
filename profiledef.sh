#!/usr/bin/env bash

iso_name="kwimy"
iso_label="KWIMY_$(date +%Y%m)"
iso_publisher="kwimy"
iso_application="kwimy installer"
version_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/VERSION"
if [[ -f "$version_file" ]]; then
  iso_version="$(head -n 1 "$version_file" | tr -d '[:space:]')"
else
  echo "Error: Missing ISO version file at $version_file" >&2
  exit 1
fi
if [[ -z "$iso_version" ]]; then
  echo "Error: ISO version file is empty: $version_file" >&2
  exit 1
fi
install_dir="arch"
work_dir="work"
out_dir="out"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.grub')
arch="x86_64"
pacman_conf="pacman.conf"

if [[ -n "${KWIMY_BUILD_JOBS:-}" ]]; then
  echo "DEBUG: profiledef.sh sees KWIMY_BUILD_JOBS=${KWIMY_BUILD_JOBS}" >&2
  airootfs_image_tool_options=('-processors' "${KWIMY_BUILD_JOBS}")
fi

file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/usr/bin/kwimy-installer"]="0:0:755"
  ["/usr/local/bin/kwimy-terminal"]="0:0:755"
  ["/usr/local/bin/kwimy-launcher"]="0:0:755"
)
