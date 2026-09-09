#!/usr/bin/env bash
# État de la flotte : boards enregistrées, déploiements récents, statut.
#
# Références :
#   - rp-cli boards list | boards get
#   - rp-cli deployments list | deployments get
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/config/.env"

echo "=== Boards (flotte ${MODEL_BOARD}) ==="
rp-cli boards list --model-board "$MODEL_BOARD" || rp-cli boards list

echo
echo "=== Déploiements récents ==="
rp-cli deployments list | head -20

echo
echo "=== Conseil ==="
echo "  - boards acceptées ? elles apparaissent dans Mender côté factory."
echo "  - l'état d'un déploiement : rp-cli deployments get <id>"
echo "  - côté cible : ./scripts/target/check.sh"