#!/usr/bin/env bash
# Provisionnement de la carte de référence (RPi3B+) pour le projet OTA redpesk.
#
# À exécuter SUR LA CIBLE (root, redpesk OS déjà flashé et booté).
# Configuration documentée :
#   docs.redpesk.bzh docs/en/master/redpesk-os/os-ota/1-mender-redpesk.html
#
# Usage (sur la carte) :
#   ./scripts/target/provision.sh <device_type> [chemin_clé_privée.pem]
#     device_type : device type Mender du model board (défaut flotte)
#     clé privée  : optionnelle. Si absente, on pose l'identité sans Mender
#                   (mender-client peut être indisponible sur l'image, voir
#                   docs/mender-packaging-corn3.md).
set -euo pipefail

DEVICE_TYPE="${1:-rpi3b-flotte}"
KEY_FILE="${2:-}"

# 1. Vérifier que la carte est bien sous redpesk OS
grep -q "redpesk" /etc/os-release || {
    echo "ERREUR : /etc/os-release ne mentionne pas redpesk. Carte incompatible." >&2
    exit 1
}

# 2. Activer la config factory (swap redpesk-config vers la factory)
FACTORY_URL="${FACTORY_URL:-https://community-app.redpesk.bzh}"
dnf -y --nobest --nogpgcheck \
    --repofrompath "CONFIG,${FACTORY_URL}/download/redpesk/redpesk-config/" \
    --repo CONFIG swap redpesk-config redpesk-config

# 3. Installer le client Mender (non-bloquant : mender-client peut manquer)
#    Sur corn 3.x, mender-redpesk exige mender-client >= 5.0.0 non fourni par
#    les dépôts publics -> on ne casse pas le provisionnement pour autant ;
#    l'OTA complet sera validé quand le paquet sera disponible (retour redpesk).
dnf install -y mender-redpesk 2>/dev/null \
    || echo "AVERTISSEMENT : mender-redpesk non installable (mender-client >= 5.0.0 absent des dépôts corn 3.x)"
dnf install -y mender-connect 2>/dev/null \
    || echo "(mender-connect absent des dépôts : optionnel, ignoré)"

# 4. Enregistrer l'identité (device type + clé) si le client est présent
#    mender.conf de corn 3.x référence /var/lib/mender/device_type : on le pose
#    aussi à cet emplacement (compatibilité).
set_device_type() {
    install -d /etc/mender /var/lib/mender
    echo "device_type=${DEVICE_TYPE}" > /etc/mender/device_type
    echo "device_type=${DEVICE_TYPE}" > /var/lib/mender/device_type
}
if [ -x /usr/bin/mender-init.sh ]; then
    if [ -n "$KEY_FILE" ] && [ -f "$KEY_FILE" ]; then
        /usr/bin/mender-init.sh --force -d "$DEVICE_TYPE" -k "$(cat "$KEY_FILE")"
        set_device_type
    else
        echo "mender-init.sh présent mais clé non fournie : device type posé seul."
        set_device_type
    fi
else
    echo "mender-init.sh absent (client Mender non installé) :"
    echo "on pose uniquement le device type (config manuelle)."
    set_device_type
fi

# 5. Activer les services (uniquement s'ils existent)
systemctl enable --now mender-authd mender-updated mender-connect 2>/dev/null || true

# 6. Vérification
echo "--- identité Mender ---"
cat /etc/mender/device_type 2>/dev/null || cat /var/lib/mender/device_type 2>/dev/null || true

echo
echo "✅ Carte provisionnée (device type ${DEVICE_TYPE})."
echo "   OTA Mender complet : en attente de mender-client (voir docs/mender-packaging-corn3.md)."