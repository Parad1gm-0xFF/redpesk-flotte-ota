#!/usr/bin/env bash
# Prépare le build Yocto (scarthgap) : qemuarm64-secureboot + secure boot ARM
# (TF-A + OP-TEE + U-Boot) + layout Mender A/B.
# Usage : setup-build.sh [racine_yocto]   (défaut : /mnt/yocto)
#
# Idempotent : clone les dépôts manquants, écrit local.conf et bblayers.conf.
# Contexte complet : docs/yocto-qemuarm64-secureboot-mender.md
set -euo pipefail

YOCTO_DIR="${1:-/mnt/yocto}"
BRANCH="scarthgap"
BUILD_DIR="$YOCTO_DIR/build"

mkdir -p "$YOCTO_DIR"
cd "$YOCTO_DIR"

clone() {
    local url="$1" dir="$2"
    if [ ! -d "$dir/.git" ]; then
        echo "=== clone $dir ($BRANCH) ==="
        git clone --branch "$BRANCH" --depth 1 "$url" "$dir"
        # un dépôt cloné sur exFAT arrive sans symlinks : forcer puis restaurer
        git -C "$dir" config core.symlinks true
        git -C "$dir" reset --hard
    fi
}

clone https://git.yoctoproject.org/poky poky
clone https://git.yoctoproject.org/meta-arm meta-arm
clone https://github.com/openembedded/meta-openembedded meta-openembedded
clone https://github.com/mendersoftware/meta-mender meta-mender

mkdir -p "$BUILD_DIR/conf"

# --- local.conf (créé par oe-init-build-env s'il n'existe pas encore) ---
LOCAL_CONF="$BUILD_DIR/conf/local.conf"
if [ ! -f "$LOCAL_CONF" ]; then
    set +u
    source "$YOCTO_DIR/poky/oe-init-build-env" "$BUILD_DIR" >/dev/null
    set -u
fi
if ! grep -q "Démo redpesk : BSP ARM" "$LOCAL_CONF"; then
    echo "=== ajout de la config démo dans local.conf ==="
    cat >> "$LOCAL_CONF" <<'EOF'

# ===== Démo redpesk : BSP ARM + secure boot + Mender A/B =====
MACHINE = "qemuarm64-secureboot"

# meta-mender : image A/B + artefact OTA
MENDER_ARTIFACT_NAME = "release-1"
INHERIT += "mender-full"
INIT_MANAGER = "systemd"

# Partition boot FAT : 64 Mo (le noyau arm64 Image fait ~25 Mo, défaut 16 Mo trop petit)
MENDER_BOOT_PART_SIZE_MB = "64"

# QEMU virt expose le disque en /dev/vda (et non /dev/mmcblk0) : aligne le fstab Mender
MENDER_STORAGE_DEVICE = "/dev/vda"

# QEMU fournit son DTB à U-Boot, pas de paquet kernel-devicetree
MACHINE_ESSENTIAL_EXTRA_RDEPENDS:remove = "kernel-devicetree"

# Doit être non vide (utilisé après -E dans l'intercept fc-cache)
FONTCONFIG_CACHE_ENV = "FC_DEBUG=1"
EOF
fi

# --- bblayers.conf ---
BBLAYERS_CONF="$BUILD_DIR/conf/bblayers.conf"
if ! grep -q "BSP ARM + secure boot + Mender A/B" "$BBLAYERS_CONF" 2>/dev/null; then
    echo "=== écriture de bblayers.conf ==="
    cat > "$BBLAYERS_CONF" <<EOF
# LAYERS (Yocto scarthgap) : BSP ARM + secure boot + Mender A/B
POKY = "$YOCTO_DIR"

BBPATH = "\${TOPDIR}"
BBFILES ?= ""
BBLAYERS ?= " \\
  \${POKY}/poky/meta \\
  \${POKY}/poky/meta-poky \\
  \${POKY}/poky/meta-yocto-bsp \\
  \${POKY}/meta-arm/meta-arm \\
  \${POKY}/meta-arm/meta-arm-toolchain \\
  \${POKY}/meta-arm/meta-arm-bsp \\
  \${POKY}/meta-openembedded/meta-oe \\
  \${POKY}/meta-openembedded/meta-python \\
  \${POKY}/meta-openembedded/meta-networking \\
  \${POKY}/meta-mender/meta-mender-core \\
  "
EOF
fi

# --- intercepts qemu-user ---
# Rien à neutraliser : sur cette image (core-image-minimal + mender-full), le
# seul intercept qui s'exécute est update_udev_hwdb, et il passe avec le script
# d'origine. Les intercepts fontconfig / gio / gtk ne se déclenchent que si les
# paquets correspondants sont installés. Si un build échoue malgré tout sur un
# intercept, restaurer les scripts d'origine :
#   git -C "$YOCTO_DIR/poky" checkout -- scripts/postinst-intercepts/

echo
echo "Prêt. Build : scripts/yocto/build.sh $YOCTO_DIR"