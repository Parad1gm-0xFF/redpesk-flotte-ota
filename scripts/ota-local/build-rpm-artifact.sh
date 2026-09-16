#!/usr/bin/env bash
# Crée un artefact Mender "redpesk-payload" (RPM) localement, sans la factory.
# Usage : build-rpm-artifact.sh <rpm_file> <device_type> [out_dir]
#   rpm_file    : RPM aarch64 cible (doit être SIGNÉ, cf. note ci-dessous)
#   device_type : ex. rpi3b-flotte_91c8e506
#
# Prérequis : docker (image mendersoftware/mender-ci-tools:master).
#
# NOTE signature : le module redpesk-payload lance
#   rpm --define='%_pkgverify_level all' -U --force
# donc le RPM DOIT être signé, et la clé publique importée sur la cible
# (rpm --import <pubkey.asc>). Pour signer :
#   docker run --rm -v "$PWD":/w -w /w almalinux:9 bash -c \
#     "dnf install -y gnupg2 rpm-sign && \
#      gpg --batch --gen-key /keyparams && \
#      rpm --define '_gpg_name <email>' --addsign <rpm> && \
#      gpg --armor --export <email> > ota-pub.asc"
set -euo pipefail

RPM="${1:?Usage: build-rpm-artifact.sh <rpm_file> <device_type> [out_dir]}"
DEVICE_TYPE="${2:?device_type manquant}"
OUT_DIR="${3:-$(pwd)/ota-out}"
RPM="$(realpath "$RPM")"

[ -f "$RPM" ] || { echo "RPM introuvable: $RPM" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/payload" "$OUT_DIR"

printf 'VERSION=2\nPAYLOAD_TYPE="rpm-os"\n' > "$WORK/payload/metadata"
cp "$RPM" "$WORK/payload/"

echo "=== création de l'artefact redpesk-payload (device_type=${DEVICE_TYPE}) ==="
docker run --rm \
    -v "$WORK/payload":/payload \
    -v "$OUT_DIR":/out \
    mendersoftware/mender-ci-tools:master \
    mender-artifact write module-image \
    -T redpesk-payload \
    -t "$DEVICE_TYPE" \
    -o /out/stn-payload-1.0.mender -n stn-payload-1.0 \
    -f /payload/metadata -f "/payload/$(basename "$RPM")"

echo "=== artefact produit ==="
ls -la "$OUT_DIR/stn-payload-1.0.mender"
echo "Déploiement : scp sur la cible + 'rpm --import <pubkey>' puis 'mender-update install'."