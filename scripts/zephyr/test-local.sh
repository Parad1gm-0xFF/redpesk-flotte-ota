#!/usr/bin/env bash
# Lance un firmware Zephyr (buildé par la factory redpesk) sous QEMU local.
# Usage : test-local.sh <repertoire_firmwares>
#   repertoire_firmwares : dossier contenant zephyr-qemu-locore.elf +
#                          zephyr-qemu-main.elf (extrait du RPM)
set -euo pipefail

FW_DIR="${1:-./fw/lib/firmware}"
[ -f "$FW_DIR/zephyr-qemu-locore.elf" ] || { echo "erreur : zephyr-qemu-locore.elf absent" >&2; exit 1; }
[ -f "$FW_DIR/zephyr-qemu-main.elf" ] || { echo "erreur : zephyr-qemu-main.elf absent" >&2; exit 1; }

command -v qemu-system-x86_64 >/dev/null || { echo "qemu-system-x86_64 absent" >&2; exit 1; }

cd "$FW_DIR"
# Syntaxe corrigée par rapport à la doc redpesk (voir docs/zephyr-qemu-demo.md) :
#   -serial chardev:con   (et non "chardev=con")
#   -mon chardev=con      (et non "chardev:con")
exec timeout "${QEMU_TIMEOUT:-25}" qemu-system-x86_64 \
    -m 32 \
    -cpu qemu64,+x2apic,mmx,mmxext,sse,sse2 \
    -machine q35 \
    -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
    -no-reboot -nographic -machine acpi=off \
    -net none \
    -pidfile qemu.pid \
    -chardev stdio,id=con,mux=on \
    -serial chardev:con \
    -mon chardev=con,mode=readline \
    -device loader,file=./zephyr-qemu-main.elf \
    -smp cpus=2 \
    -kernel ./zephyr-qemu-locore.elf