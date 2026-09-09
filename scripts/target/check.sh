#!/usr/bin/env bash
# Diagnostic OTA sur une carte de la flotte.
# À exécuter SUR LA CIBLE (root, redpesk OS).
set -euo pipefail

echo "=== OS ==="
grep PRETTY_NAME /etc/os-release

echo
echo "=== Device type Mender ==="
cat /etc/mender/device_type 2>/dev/null || cat /var/lib/mender/device_type 2>/dev/null || echo "introuvable"

echo
echo "=== Partitions (A/B) ==="
# Mender utilise 2 partitions racines A/B ; on affiche laquelle est active
ROOT_DEV="$(findmnt -no SOURCE /)"
echo "root actuellement monté depuis : ${ROOT_DEV}"

echo
echo "=== Services Mender ==="
systemctl --no-pager --quiet is-active mender-authd && echo "mender-authd   : actif" || echo "mender-authd   : INACTIF"
systemctl --no-pager --quiet is-active mender-updated && echo "mender-updated : actif" || echo "mender-updated : INACTIF"
systemctl --no-pager --quiet is-active mender-connect && echo "mender-connect : actif" || echo "mender-connect : INACTIF"

echo
echo "=== Dernier log de mise à jour ==="
journalctl -u mender-updated --no-pager -n 5 2>/dev/null || true

echo
echo "=== Conseil ==="
echo "  update en cours ?  journalctl -u mender-updated -f"
echo "  rollback forcé ?    ./scripts/target/rollback.sh"