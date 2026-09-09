#!/usr/bin/env bash
# Provisionne la flotte dans la redpesk factory : model board + boards.
#
# Prérequis :
#   - rp-cli configuré (rp-cli onboard), voir docs/redpesk-cli.md
#   - config/.env renseigné (cp config/.env.example config/.env)
#
# Référence des commandes : docs.redpesk.bzh/docs/en/master/redpesk-factory/rp_cli/4_commands-list.html
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=config/.env.example
source "${SCRIPT_DIR}/config/.env"

# --- 1. Projet ---
if ! rp-cli projects get "$RP_PROJECT" >/dev/null 2>&1; then
    echo "[1/5] Création du projet ${RP_PROJECT}..."
    rp-cli projects add "$RP_PROJECT"
else
    echo "[1/5] Projet ${RP_PROJECT} existant, passe."
fi

# --- 2. Model board (<=> device type Mender) ---
if rp-cli board-models list | grep -q "^${MODEL_BOARD}[[:space:]]"; then
    echo "[2/5] Model board ${MODEL_BOARD} existant, passe."
else
    echo "[2/5] Création du model board ${MODEL_BOARD} (device type ${MODEL_BOARD})..."
    rp-cli board-models add --name "$MODEL_BOARD" --configuration ./factory/models-board.yml
fi

# --- 3. Boards ---
echo "[3/5] Ajout / mise à jour des boards (boards.csv)..."
while IFS=, read -r name mac notes; do
    # sauter l'en-tête et les lignes vides
    [[ "$name" == "name" || -z "$name" ]] && continue
    if rp-cli boards list | grep -q "${mac}"; then
        echo "   board ${name} (${mac}) déjà présente, passe."
    else
        echo "   ajout board ${name} (${mac})..."
        rp-cli boards add --name "$name" --mac "$mac" --model-board "$MODEL_BOARD" --notes "$notes"
    fi
done < "${SCRIPT_DIR}/factory/boards.csv"

# --- 4. Vérification ---
echo "[4/5] État de la flotte :"
rp-cli boards list
echo "[5/5] Terminé. Les boards apparaissent pré-autorisées ; "
echo "      elles seront acceptées à la première connexion Mender (voir status.sh)."