#!/usr/bin/env bash
# Lance une VM redpesk OS (x86_64) membre de la flotte OTA simulée.
#
# Chaque VM simule une board physique de la flotte : elle s'enregistre dans la
# factory avec sa propre identité Mender (MAC + device type + clé privée).
#
# Prérequis (poste de dev) :
#   - qemu-system-x86_64 + OVMF (edk2-ovmf) installés
#   - une image redpesk OS x86_64 téléchargée (voir docs/simulate-fleet.md)
#
# Usage :
#   ./scripts/vm-fleet/launch-vm.sh <index> [image.raw]
#   Ex : ./scripts/vm-fleet/launch-vm.sh 1          # port SSH 3301, MAC rpi3b-01
#
# Référence : docs.redpesk.bzh/docs/en/master/redpesk-os/boards/docs/boards/qemu.html
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/config/.env"

INDEX="${1:?Usage: launch-vm.sh <index> [image.raw]}"
IMG="${2:-${SCRIPT_DIR}/vm-fleet/Redpesk-OS.img}"

[ -f "$IMG" ] || { echo "ERREUR : image $IMG absente (voir docs/simulate-fleet.md)." >&2; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "ERREUR : qemu-system-x86_64 absent." >&2; exit 1; }

OVMF="/usr/share/OVMF/OVMF_CODE_4M.fd"
[ -f "$OVMF" ] || OVMF="/usr/share/OVMF/OVMF_CODE.fd"
[ -f "$OVMF" ] || OVMF="/usr/share/qemu/OVMF.fd"
[ -f "$OVMF" ] || { echo "ERREUR : OVMF introuvable (installer edk2-ovmf ou ovmf)." >&2; exit 1; }

OVMF_VARS="/usr/share/OVMF/OVMF_VARS_4M.fd"
[ -f "$OVMF_VARS" ] || OVMF_VARS="/usr/share/OVMF/OVMF_VARS.fd"
[ -f "$OVMF_VARS" ] || OVMF_VARS="/usr/share/qemu/OVMF_vars.fd"
[ -f "$OVMF_VARS" ] || { echo "ERREUR : OVMF_VARS introuvable." >&2; exit 1; }

# Copie locale de VARS (QEMU ne doit pas écrire dans le fichier système)
VARS_RW="${SCRIPT_DIR}/vm-fleet/OVMF_VARS_${INDEX}.fd"
cp -f "$OVMF_VARS" "$VARS_RW"

# Identité de la VM : une board par index de la flotte
PORT_SSH=$((3300 + INDEX))
BOARD_NAME="rpi3b-${INDEX}"
# MAC dans la plage OUI de la foundation Raspberry Pi (b8:27:eb:..)
MAC="b8:27:eb:00:00:$(printf '%02x' "$INDEX")"

echo "=== Démarrage VM ${BOARD_NAME} (board simulée) ==="
echo "  SSH    : ssh -p ${PORT_SSH} root@localhost"
echo "  MAC    : ${MAC}"
echo "  Image  : ${IMG}"
echo "  Ctrl-A X pour quitter la console"

exec qemu-system-x86_64 \
    -drive file="$IMG",format=raw \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF" \
    -drive if=pflash,format=raw,file="$VARS_RW" \
    -enable-kvm -m 2048 \
    -cpu Skylake-Client-v4 \
    -smp 4 \
    -vga std \
    -device virtio-rng-pci \
    -serial mon:stdio \
    -serial null \
    -net nic,macaddr="$MAC" \
    -net user,hostfwd=tcp::"$PORT_SSH"-:22