#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
VM_NAME="kwimy"
DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"
ISO_PATH="${ISO_PATH:-}"
ISO_DIR="${ISO_DIR:-$ROOT_DIR/kwimy-iso/out}"
ISO_GLOB="${ISO_GLOB:-kwimy-*.iso}"

RAM_MB=4024
CPUS=4
DISK_SIZE_GB=40

if ! command -v virt-install >/dev/null 2>&1; then
  echo "Error: virt-install not found. Install virt-manager/libvirt packages."
  exit 1
fi

if ! command -v virsh >/dev/null 2>&1; then
  echo "Error: virsh not found. Install libvirt."
  exit 1
fi

if [ -z "$ISO_PATH" ]; then
  ISO_PATH=$(ls -t "${ISO_DIR}/${ISO_GLOB}" 2>/dev/null | head -n 1 || true)
fi

if [ -z "$ISO_PATH" ] || [ ! -f "$ISO_PATH" ]; then
  echo "Error: ISO not found. Set ISO_PATH or build ISO into ${ISO_DIR}."
  exit 1
fi

echo "Using ISO: $ISO_PATH"

if virsh dominfo "$VM_NAME" >/dev/null 2>&1; then
  if virsh domstate "$VM_NAME" 2>/dev/null | grep -qi "running"; then
    virsh destroy "$VM_NAME" || true
  fi
  virsh undefine "$VM_NAME" --nvram || true
fi

if [ -f "$DISK_PATH" ]; then
  rm -f "$DISK_PATH"
fi

virt-install \
  --name "$VM_NAME" \
  --memory "$RAM_MB" \
  --vcpus "$CPUS" \
  --cpu host-model \
  --machine q35 \
  --boot uefi \
  --cdrom "$ISO_PATH" \
  --disk path="$DISK_PATH",size="$DISK_SIZE_GB",format=qcow2,bus=virtio \
  --os-variant archlinux \
  --network network=default,model=virtio \
  --graphics spice \
  --video virtio \
  --rng /dev/urandom \
  --noautoconsole
