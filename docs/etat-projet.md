# État du projet : finalité « une seule carte » (13/09/2026).

## Décision

Le projet est finalisé sur le périmètre d'**une carte de référence unique**
(RPi3B+ réel), plutôt que sur une « flotte ». Justification :

- Les simulations VM QEMU **ne peuvent pas faire l'OTA Mender** (`mender-client`
  absent des dépôts redpesk publics) : multiplier les VMs ne démontrerait
  jamais l'OTA et n'apportait rien à la finalité.
- Mender gère un seul device exactement comme une flotte : enregistrement,
  device type, inventaire, déploiement, rollback. Une carte suffit pour une
  démonstration honnête.
- Tout l'outillage est réellement exécuté sur **une** carte physique.

## Réalisé (exécuté réellement)

| Élement | État |
|---|---|
| RPi3B+ sous redpesk corn 3.0 | ✅ boots, WiFi opérationnel (wlan0, tient au reboot) |
| `redpesk-config` -> factory Community (1.5.1-5.community) | ✅ installé |
| Device type `rpi3b-flotte` | ✅ posé (`/etc/mender/device_type` + `/var/lib/mender/device_type`) |
| `target/provision.sh` | ✅ exécuté sur la carte (non-bloquant) |
| Application Zephyr dans la factory | ✅ build 55090 + preuve QEMU (Zephyr 4.2.1, Hello World qemu_x86_64) |
| Scripts factory (`provision.sh`, `status.sh`, `deploy.sh`) | ✅ rédigés, prêts (déclaration board = MAC du RPi) |

## Non réalisé (blocage externe externe documenté)

| Élement | État | Bloquant |
|---|---|---|
| Install `mender-redpesk` sur la carte | ❌ | `mender-client >= 5.0.0` absent des dépôts redpesk publics (corn 3.0 + 3.1, aarch64 + x86_64) |
| Enregistrement Mender + déploiement OTA effectif | ❌ | dépend du point précédent |

Remontée faite le 09/09 à `support@redpesk.bzh` (+ cc Fulup). Détail :
`docs/mender-packaging-corn3.md`.

## Ce qui finalisera le projet (quand redpesk répondra)

1. Installer `mender-redpesk`/`mender-client` sur la carte (si paquet fourni),
2. Déclarer la board (MAC) dans la factory (`scripts/factory/provision.sh`),
3. Accepter l'enregistrement Mender, créer un artifact et le déployer
   (`scripts/factory/deploy.sh`),
4. Observer l'update A/B + rollback (`scripts/target/check.sh`, `rollback.sh`).

## Note : nom du dépôt

Le dépôt GitHub s'appelle encore `redpesk-flotte-ota` (nom d'origine). Le
périmètre documenté est désormais « une carte de référence » ; un éventuel
renommage (ex. `redpesk-ota-node`) est laissé à discrétion, sans blocage.