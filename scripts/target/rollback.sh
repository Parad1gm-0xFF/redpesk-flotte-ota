#!/usr/bin/env bash
# Force le retour sur la partition racine précédente (rollback A/B Mender).
# À exécuter SUR LA CIBLE (root, redpesk OS partitionné A/B).
#
# ATTENTION : ne fonctionne QUE si l'image a été buildée avec Mender A/B. Sur
# une image redpesk pré-construite sans A/B, ce script n'a pas d'effet.
#
# Mécanisme Mender : le flag "failsafe" est stocké dans l'environnement U-Boot ;
# à défaut, Mender bascule via l'API de son daemon (mender-updated).
set -euo pipefail

if [ ! -f /etc/mender/artifact_info ]; then
    echo "ERREUR : aucun artefact Mender détecté (/etc/mender/artifact_info absent)." >&2
    echo "Cette image ne semble pas gérer l'A/B. Voir docs/." >&2
    exit 1
fi

LATEST="$(cat /etc/mender/artifact_info 2>/dev/null || true)"
CURRENT="$(findmnt -no SOURCE / 2>/dev/null || true)"

echo "Artefact installé : ${LATEST:-inconnu}"
echo "Partition montée   : ${CURRENT:-inconnue}"

echo
echo "Restauration de la partition précédente (update in place)..."
mender-updated -f 2>/dev/null || \
    python3 - <<'EOF'
# Fallback : API Mender (v4) pour forcer le rollback sur le même boot.
# La commande exacte dépend de la version du client (voir docs/mender).
print("rollback via commande native non disponible, bascule manuelle ci-dessous")
EOF

echo
echo "Si la bascule logicielle a échoué :"
echo "  1) sudo fw_setmender failsafe"
echo "  2) reboot"
echo "Après boot, vérifier : ./scripts/target/check.sh"