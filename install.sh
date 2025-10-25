#!/bin/bash
set -e
apt update
DEBIAN_FRONTEND=noninteractive apt install -y qemu-system-x86 qemu-utils cloud-image-utils curl wget
chmod +x /home/container/vm.sh
echo "✅ QEMU & dependencies installed"
