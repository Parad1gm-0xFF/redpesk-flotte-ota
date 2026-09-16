# État du projet : carte de référence unique (mis à jour 16/09/2026).

## Décision

Le projet est centré sur **une carte de référence unique** (RPi3B+ réel),
plutôt que sur une « flotte » :

- Mender gère un seul device exactement comme une flotte (enregistrement,
  device type, inventaire, déploiement, rollback) : une carte suffit.
- Tout l'outillage est réellement exécuté sur **une** carte physique.

## Réalisé (exécuté réellement)

| Élément | État |
|---|---|
| RPi3B+ sous redpesk corn 3.0 | ✅ boots, WiFi opérationnel (tient au reboot) |
| `redpesk-config` -> factory Community (1.5.1-5.community) | ✅ installé |
| Client Mender (`mender-client 5.0.3`, `mender-connect`, `mender-redpesk`) | ✅ via repo `redpesk-third-party` (`echo 1 > /etc/dnf/vars/redpesk_third_party`) |
| Services Mender (`mender-authd`, `mender-updated`, `mender-connect`) | ✅ actifs |
| **Authentification device auprès de la factory** | ✅ (« Successfully received new authorization data », inventaire soumis, poll actif) |
| Device type | ✅ `<model_name>_<model_id>` = `rpi3b-flotte_91c8e506` (valeur attendue par la factory) |
| **Déploiement factory** (`rp-cli project-releases deploy ... --rpms`) | ✅ accepté par la factory |
| **OTA local (standalone)** | ✅ artefact `single-file` ET `redpesk-payload` (RPM signé) installés/committés (`docs/artefact-local.md`) |
| Application Zephyr dans la factory | ✅ build 55090 + preuve QEMU (Zephyr 4.2.1) |

## Points restants (non bloquants)

- `jq` manquant sur l'image (inventaire `repos-info`, non bloquant).
- Activer `gpgcheck` sur la board pour vérifier les signatures factory.
- Déploiement **managed** via `mender-cli` : nécessite des identifiants sur
  `community-mender.redpesk.bzh` (serveur joignable, API présente).

## Leçon / correction

Un premier essai de déploiement avait produit une erreur serveur qualifiée à
tort de « bug plateforme ». En relisant la procédure, la cause était une
**option manquante** (`--rpms`) : le déploiement factory fonctionne.

## Note : nom du dépôt

Le dépôt GitHub s'appelle encore `redpesk-flotte-ota` (nom d'origine) ; le
périmètre documenté est « carte de référence unique ».