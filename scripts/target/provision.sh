#!/usr/bin/env bash
# Provisionnement d'une carte RPi3B+ pour rejoindre la flotte OTA.
#
# À exécuter SUR LA CIBLE (root, redpesk OS déjà flashé et booté) ou via les
# commandes indiquées une par une. Configuration documentée sur :
#   docs.redpesk.bzh docs/en/master/redpesk-os/os-ota/1-mender-redpesk.html
#
# Usage (sur la carte) :
#   ./scripts/target/provision.sh <device_type> <chemin_clé_privée.pem>
set -euo pipefail

DEVICE_TYPE="${1:?Usage: provision.sh <device_type> <chemin_clé_privée.pem>}"
KEY_FILE="${2:?il manque le fichier de clé privée Mender (généré côté factory)}"

# 1. Vérifier que la carte est bien sous redpesk OS
grep -q "redpesk" /etc/os-release || {
    echo "ERREUR : /etc/os-release ne mentionne pas redpesk. Carte incompatible." >&2
    exit 1
}

# 2. Installer le client Mender + la config factory
dnf install -y mender-redpesk mender-connect
FACTORY_URL="${FACTORY_URL:-https://community-app.redpesk.bzh}"
dnf --nobest --nogpgcheck \
    --repofrompath "CONFIG,${FACTORY_URL}/download/redpesk/redpesk-config/" \
    --repo CONFIG swap redpesk-config redpesk-config

# 3. Enregistrer l'identité Mender (device type + clé privée)
/usr/bin/mender-init.sh --force -d "$DEVICE_TYPE" -k "$(cat "$KEY_FILE")"

# 4. Activer les services
systemctl enable --now mender-authd mender-updated mender-connect 2>/dev/null || true

# 5. Vérification
echo "--- identité Mender ---"
cat /etc/mender/device_type 2>/dev/null || cat /var/lib/mender/device_type 2>/dev/null || true
systemctl --no-pager status mender-authd --no-pager | head -5

echo
echo "✅ Carte enregistrée (device type ${DEVICE_TYPE})."
echo "   Suivre l'authentification : journalctl -u mender-authd -f"