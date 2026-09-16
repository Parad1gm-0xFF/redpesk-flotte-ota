#!/usr/bin/env bash
# Crée un artefact Mender "single-file" localement (sans la factory).
# Usage : build-artifact.sh <device_type> [out_dir]
#   device_type : ex. rpi3b-flotte_91c8e506 (doit matcher le device_type factory)
#
# Prérequis : docker. Utilise l'image officielle mendersoftware/mender-ci-tools.
set -euo pipefail

DEVICE_TYPE="${1:?Usage: build-artifact.sh <device_type> [out_dir]}"
OUT_DIR="${2:-$(pwd)/ota-out}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/payload" "$OUT_DIR"
cd "$WORK/payload"
printf '/root' > dest_dir
printf 'ota-demo.txt' > filename
printf '0644' > permissions
printf 'Hello OTA local — artefact Mender hors factory, %s\n' "$(date)" > ota-demo.txt

echo "=== création de l'artefact (device_type=${DEVICE_TYPE}) ==="
docker run --rm \
    -v "$WORK/payload":/payload \
    -v "$OUT_DIR":/out \
    mendersoftware/mender-ci-tools:master \
    mender-artifact write module-image \
    -T single-file \
    -t "$DEVICE_TYPE" \
    -o /out/ota-demo-1.0.mender -n ota-demo-1.0 \
    -f /payload/dest_dir -f /payload/filename \
    -f /payload/permissions -f /payload/ota-demo.txt

echo "=== artefact produit ==="
ls -la "$OUT_DIR/ota-demo-1.0.mender"
echo "Déploiement : scp sur la cible, puis 'mender-update install' (mode standalone)."