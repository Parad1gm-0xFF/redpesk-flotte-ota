#!/usr/bin/env bash
# Build l'image Yocto (qemuarm64-secureboot + secure boot ARM + Mender A/B)
# et son artefact OTA.
# Usage : build.sh [racine_yocto]   (défaut : /mnt/yocto)
#
# Prérequis : avoir lancé setup-build.sh au préalable.
set -euo pipefail

YOCTO_DIR="${1:-/mnt/yocto}"
BUILD_DIR="$YOCTO_DIR/build"

[ -f "$BUILD_DIR/conf/local.conf" ] || { echo "Config absente : lancer setup-build.sh d'abord"; exit 1; }

set +u
source "$YOCTO_DIR/poky/oe-init-build-env" "$BUILD_DIR" >/dev/null
set -u

bitbake core-image-minimal

D="$BUILD_DIR/tmp/deploy/images/qemuarm64-secureboot"
echo
echo "=== artefacts ==="
ls -lh "$D"/core-image-minimal-qemuarm64-secureboot.uefiimg \
       "$D"/core-image-minimal-qemuarm64-secureboot.mender 2>/dev/null
echo
echo "Boot : scripts/yocto/boot-qemu.sh $YOCTO_DIR"