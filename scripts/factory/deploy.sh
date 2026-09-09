#!/usr/bin/env bash
# Déploie un release redpesk sur la flotte (OTA Mender).
#
# Étapes :
#   1. release du projet (build des artefacts / image)
#   2. déploiement du release sur le model board (=> toutes les boards du device type)
#
# Références :
#   - docs.redpesk.bzh docs/en/master/redpesk-factory/projects-management/release-project.html
#   - commande : rp-cli project-releases
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config/.env"

RELEASE_MESSAGE="${1:-mise à jour de la flotte}"

echo "[1/3] Release du projet ${RP_PROJECT}..."
rp-cli projects release "$RP_PROJECT" --message "$RELEASE_MESSAGE"

echo "[2/3] Récupération du dernier release..."
LATEST=$(rp-cli project-releases list -p "$RP_PROJECT" | head -1)
echo "      release : ${LATEST}"

echo "[3/3] Déploiement OTA sur le model board ${MODEL_BOARD}..."
# Le déploiement cible le device type (toutes les boards du model board)
rp-cli project-releases deploy "$LATEST" --model-board "$MODEL_BOARD"

echo
echo "✅ Déploiement déclenché. Suivi : scripts/factory/status.sh, ou sur cible :"
echo "   journalctl -u mender-updated -f"