#!/usr/bin/env bash
# Boote l'image Mender A/B (uefiimg) en QEMU, sur une console série telnet.
# Usage : boot-qemu.sh [racine_yocto] [port]   (défaut : /mnt/yocto 4444)
#
# L'uefiimg est le disque 4 partitions (ESP + rootfs A + rootfs B + data) :
# c'est le layout Mender A/B. Le wic.qcow2 de meta-arm n'a que 2 partitions et
# tombe en emergency mode (pas de /data) : on boote donc l'uefiimg, converti en
# qcow2. Pas de -kernel : GRUB charge le noyau depuis l'ESP.
#
# Connexion : telnet 127.0.0.1 <port>   (login : root, mot de passe vide)
set -euo pipefail

YOCTO_DIR="${1:-/mnt/yocto}"
PORT="${2:-4444}"
BUILD_DIR="$YOCTO_DIR/build"
D="$BUILD_DIR/tmp/deploy/images/qemuarm64-secureboot"
IMG="$D/core-image-minimal-qemuarm64-secureboot.uefiimg"
QCOW="$BUILD_DIR/mender-uefi.qcow2"

QEMU="$(find "$BUILD_DIR/tmp/work/x86_64-linux/qemu-helper-native" \
        -name qemu-system-aarch64 -type f 2>/dev/null | head -1)"

[ -f "$IMG" ]  || { echo "Image absente : $IMG (lancer build.sh d'abord)"; exit 1; }
[ -x "$QEMU" ] || { echo "qemu-system-aarch64 introuvable (lancer build.sh d'abord)"; exit 1; }

echo "=== conversion uefiimg -> qcow2 ==="
qemu-img convert -f raw -O qcow2 "$IMG" "$QCOW"

echo "=== boot QEMU : console série telnet 127.0.0.1:$PORT ==="
echo "    connexion : telnet 127.0.0.1 $PORT   (login root, mot de passe vide)"
exec "$QEMU" \
  -machine virt,secure=on -cpu cortex-a57 -smp 4 -m 1024 -no-acpi \
  -bios "$D/flash.bin" \
  -drive file="$QCOW",if=virtio,format=qcow2 \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -object rng-random,filename=/dev/urandom,id=rng0 -device virtio-rng-pci,rng=rng0 \
  -device qemu-xhci -device usb-tablet -device usb-kbd \
  -device virtio-gpu-pci \
  -serial telnet:127.0.0.1:"$PORT",server,nowait -serial null -display none -no-reboot