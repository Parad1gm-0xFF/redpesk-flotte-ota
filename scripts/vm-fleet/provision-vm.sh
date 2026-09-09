#!/usr/bin/env bash
# Provisionne une VM redpesk comme member de la flotte OTA simulée.
#
# Réutilisable pour VM #1..#n : prendre l'index de la VM en paramètre.
# À exécuter SUR LA VM (root, redpesk OS), après launch-vm.sh <index>.
#
# Usage :
#   ./provision-vm.sh <index> [device_type] [chemin_clé_privée.pem]
#     index        : numéro de la VM (#1, #2, ...) = numéro de board
#     device_type  : device type Mender (défaut : rpi3b-flotte)
#     clé privée   : clé Mender de la board (générée côté factory). Si absente,
#                    en génère une locale (démo : l'ajouter ensuite côté factory).
#
# Référence : docs.redpesk.bzh docs/en/master/redpesk-os/os-ota/1-mender-redpesk.html
set -euo pipefail

INDEX="${1:?Usage: provision-vm.sh <index> [device_type] [clé_privée.pem]}"
DEVICE_TYPE="${2:-rpi3b-flotte}"
KEY_FILE="${3:-}"

# --- 1. Vérifier qu'on est bien sur redpesk ---
grep -q "redpesk" /etc/os-release || {
    echo "ERREUR : /etc/os-release ne mentionne pas redpesk." >&2
    exit 1
}

# --- 2. Récupérer le MAC (identité Mender) ---
MAC="$(ip link show | grep -A1 'eth0' | grep 'link/ether' | awk '{print $2}' || true)"
[ -z "$MAC" ] && MAC="$(ip -br link | grep -v lo | grep UP | head -1 | awk '{print $3}')"
echo "=== Provisionnement VM #${INDEX} ==="
echo "  device_type : ${DEVICE_TYPE}"
echo "  MAC         : ${MAC}"

# --- 3. Installer le client Mender + config factory ---
# mender-client peut être absent des repos de l'image VM x86_64 (dépendance
# non satisfaite) : on tente l'installation sans rendre le reste bloquant.
# Sur l'OS RPi réel (aarch64), mender-redpesk s'installe normalement.
dnf install -y mender-redpesk 2>/dev/null \
    || echo "AVERTISSEMENT : mender-redpesk non installable (mender-client >= 5.0.0 absent des repos x86_64 VM)"
dnf install -y mender-connect 2>/dev/null || echo "(mender-connect absent des repos : optionnel, ignoré)"
FACTORY_URL="${FACTORY_URL:-https://community-app.redpesk.bzh}"
dnf --nobest --nogpgcheck \
    --repofrompath "CONFIG,${FACTORY_URL}/download/redpesk/redpesk-config/" \
    --repo CONFIG swap redpesk-config redpesk-config

# --- 4. Clé Mender : fournie ou générée localement ---
if [ -n "$KEY_FILE" ] && [ -f "$KEY_FILE" ]; then
    KEY_ARG="-k \"$(cat "$KEY_FILE")\""
elif [ -z "$KEY_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "Clé privée non fournie : génération locale (démo)."
    PRIVKEY="/root/mender-${INDEX}.key"
    openssl genpkey -algorithm RSA -out "$PRIVKEY" -pkeyopt rsa_keygen_bits:2048
    KEY_ARG="-k \"$(cat "$PRIVKEY")\""
fi

# --- 5. Enregistrer l'identité Mender (device type + clé) ---
if [ -x /usr/bin/mender-init.sh ]; then
    eval "/usr/bin/mender-init.sh --force -d ${DEVICE_TYPE} ${KEY_ARG}"
else
    echo "mender-init.sh absent (client Mender non installé) :"
    echo "on pose uniquement le device type + clé (config manuelle)."
    echo "device_type=${DEVICE_TYPE}" > /etc/mender/device_type
    install -d /etc/mender
    [ -n "${KEY_ARG}" ] && echo "clé privée stockée séparément (non appliquée sans client)."
fi

# --- 6. Activer les services ---
systemctl enable --now mender-authd mender-updated mender-connect 2>/dev/null || true

# --- 7. Vérification ---
echo
echo "=== Identité Mender ==="
cat /etc/mender/device_type 2>/dev/null || cat /var/lib/mender/device_type 2>/dev/null || true
systemctl --no-pager status mender-authd --no-pager | head -4

echo
echo "✅ VM #${INDEX} provisionnée (device type ${DEVICE_TYPE}, MAC ${MAC})."
echo "   Côté factory : créer/accepter la board avec ce MAC."
echo "   Suivre : journalctl -u mender-authd -f"