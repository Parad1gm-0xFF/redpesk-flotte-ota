#!/usr/bin/env bash
# Demarre le serveur Mender self-hosted (Docker Compose) et cree l'admin.
# Usage : up.sh [racine] [mot_de_passe_admin]   (defaut : /mnt/yocto)
#
# Points cles :
#   - MONGO_VERSION=7.0 : mongo:8.0 ne demarre pas sur kernel >= 6.19
#     (TCMalloc vendu, SERVER-121912).
#   - /etc/hosts doit contenir docker.mender.io -> 127.0.0.1 (sinon utiliser
#     curl --resolve cote hote).
set -euo pipefail

BASE="${1:-/mnt/yocto}"
PASSWORD="${2:-redpeskDemo2026}"
REPO="$BASE/mender-server"
VERSION="v4.1.0"
ADMIN="admin@docker.mender.io"

if [ ! -d "$REPO/.git" ]; then
    echo "=== clone mender-server $VERSION ==="
    git clone -b "$VERSION" --depth 1 https://github.com/mendersoftware/mender-server.git "$REPO"
fi

cd "$REPO"

echo "=== /etc/hosts (a faire une fois, sudo) ==="
grep -q docker.mender.io /etc/hosts || \
    echo "  echo '127.0.0.1 docker.mender.io s3.docker.mender.io' | sudo tee -a /etc/hosts"

echo "=== demarrage du serveur ==="
MONGO_VERSION=7.0 MENDER_IMAGE_TAG="$VERSION" docker compose up -d

echo "=== attente de mongo (healthy) ==="
for i in $(seq 1 30); do
    if docker ps --format '{{.Names}} {{.Status}}' | grep -q "mender-mongo-1.*healthy"; then
        echo "mongo healthy"; break
    fi
    sleep 5
done

echo "=== creation de l'admin (idempotent) ==="
MENDER_IMAGE_TAG="$VERSION" docker compose run --rm --no-deps \
    useradm create-user --username "$ADMIN" --password "$PASSWORD" || true

echo
echo "Interface : https://docker.mender.io  (admin : $ADMIN)"
echo "API en local sans /etc/hosts : curl -k --resolve docker.mender.io:443:127.0.0.1 ..."