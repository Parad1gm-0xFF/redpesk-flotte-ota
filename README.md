# 🚚 redpesk-ota-node.

> **Carte de référence unique (Raspberry Pi 3B+)** sous **redpesk OS**,
> provisionnée et mise à jour **en bout-en-bout** via la **redpesk factory**
> et son **OTA Mender** (A/B, rollback). Démos : provisionnement réel (1 carte),
> Zephyr dans la factory, simulation VM (optionnelle).

Projet de démonstration pour un poste d'**Ingénieur Linux Embarqué
Kernel/BSP** (esprit candidature IoT.bzh, Lorient), aligné sur la plateforme
**redpesk** (factory, packaging RPM, sécurité dès le build, OTA).

---

## 🎯 Ce que le projet tente de prouver.

| Mission / compétence | Preuve dans ce dépôt |
|---|---|
| **Provisionnement réel (1 carte)** | `target/provision.sh` exécuté sur un RPi3B+ : `redpesk-config` factory, device type posé, WiFi opérationnel |
| **OTA SOTA** (Software Over The Air) | Workflow Mender : model board, board, deploy (factory), + artefact local standalone (`docs/artefact-local.md`) |
| **Gestion factory** | Scripts `rp-cli` : model board, boards, release, deploy |
| Packaging **RPM** | Specfile installant la configuration Mender et les redtests |
| **Zephyr dans la factory** | App `zephyr-hello-world` buildée (build 55090) + preuve QEMU locale (`docs/zephyr-qemu-demo.md`) |
| **Secure boot x86 + ARM** | x86 : UEFI Secure Boot OVMF (`docs/uefi-secureboot-qemu.md`) ; ARM : image Yocto `qemuarm64-secureboot` TF-A + OP-TEE + U-Boot + Mender A/B bootée en QEMU (`docs/yocto-qemuarm64-secureboot-mender.md`) |
| **OTA A/B + serveur + flotte** | OTA A/B standalone (bascule/commit/rollback), serveur Mender self-hosted (auth, inventaire, déploiement managed) et flotte QEMU déployée par vagues (`docs/mender-server-selfhosted-et-flotte.md`) |
| **Tests** | `redtests/` : tests TAP sur cible (état OTA, services, device type) |
| **Sécurité** | Clés privées jamais commitées, identité board = MAC + clé (modèle Mender), device type strict |
| **Reproductibilité** | Dossier `config/` centralisé, un fichier par cible ; scripts relançables |

---

## 🏗 Architecture.

```
┌─────────────────────────────┐       ┌─────────────────────────────────┐
│  redpesk factory (.bzh)     │       │  Carte de référence (RPi3B+)    │
│   ├── project + app RPM     │       │   ├── redpesk OS (image)        │
│   ├── model board           │◄────► │   ├── mender-client (RPM)       │
│   ├── board (MAC + clé)     │ HTTPS │   ├── device type (Mender)      │
│   └── release + deploy OTA  │       │   └── config redpesk-config     │
└─────────────────────────────┘       └─────────────────────────────────┘
         │  rp-cli (poste dev)
         ▼
   scripts/factory/*.sh        scripts/target/*.sh (à exécuter sur carte)
   scripts/zephyr/*.sh         scripts/vm-fleet/*.sh (optionnel, sans Mender)
```

- **Côté factory** : un projet redpesk contient l'application (le RPM de config)
  et l'image OS. Le model board définit le `device type` Mender, les boards sont
  les cartes identifiées par **MAC** (et pré-autorisées).
- **Côté cible (1 carte)** : `target/provision.sh` active `redpesk-config`
  (pointe vers la factory), installe `mender-redpesk` via le repo
  **`redpesk-third-party`** (`echo 1 > /etc/dnf/vars/redpesk_third_party`),
  pose le `device_type`. Le device s'authentifie auprès du serveur Mender de la
  factory (`community-mender.redpesk.bzh`), soumet son inventaire et poll.
- **Déploiement** : un `release` du projet est déployé sur le model board
  (`rp-cli project-releases deploy <release> --boards <id> -a aarch64 --rpms <pkg>`).
  Mender pousse l'update (A/B + rollback pour l'OS ; installation RPM pour les apps).

---

## 🗂 Arborescence.

```
config/                   → Configuration centralisée (factory URL, utilisateur, rp-cli)
factory/
  models-board.json       → Modèle de board (device type) pour la factory
  boards.csv              → Inventaire de la flotte (nom, MAC, notes)
scripts/
  target/
    provision.sh          → Provisionne LA carte : config factory + device type
    check.sh              → Diagnostic sur cible : services, device type, part active
    rollback.sh           → Forcer le retour sur la partition précédente (A/B)
  factory/
    provision.sh          → Déclare le model board + boards dans la factory (rp-cli)
    deploy.sh             → Release + déploiement OTA (workflow prévu)
    status.sh             → État des boards / déploiements (rp-cli)
  zephyr/
    test-local.sh         → Relance de la preuve Zephyr sous QEMU
  yocto/
    setup-build.sh        → Prépare le build Yocto (sources, local.conf, contournements)
    build.sh              → Build image qemuarm64-secureboot + artefact Mender
    boot-qemu.sh          → Boote l'image Mender A/B en QEMU (console série telnet)
  mender-server/
    up.sh                 → Démarre le serveur Mender self-hosted + crée l'admin
  vm-fleet/               → OPTIONNEL : simulation de cartes QEMU (sans Mender)
    launch-vm.sh          → Démarre une VM redpesk
    provision-vm.sh       → Provisionnement d'une VM (partiel, sans mender-client)
redtests/                 → Tests TAP exécutés par la factory sur cible
spec/                     → Specfiles RPM (package de config + redtests)
docs/                     → Notes de conception, référence des commandes rp-cli
```

---

## ✅ Démonstration (état au 13/09/2026).

### 1. Carte de référence provisionnée (exécuté).

```bash
# Sur le RPi3B+ (redpesk corn 3.0, access SSH root) :
./scripts/target/provision.sh rpi3b-flotte
```

Résultat réel (RPi3B+, WiFi 192.168.x.x) :
- `redpesk-config` 1.5.1-5.community (config factory Community active)
- `device_type=rpi3b-flotte` posé (`/etc/mender/device_type` et `/var/lib/mender/device_type`)
- WiFi opérationnel (wpa_supplicant + networkd) : la carte est joignable par SSH sans câble

### 2. Déclarer le device dans la factory.

```bash
cp config/.env.example config/.env   # renseigner FACTORY_URL, USER, …
./scripts/factory/provision.sh       # crée model board + board (MAC du RPi)
./scripts/factory/status.sh          # vérifie l'état
```

### 3. OTA (déploiement via la factory).

```bash
# release + déploiement sur le model board (--rpms requis) :
rp-cli project-releases deploy <release-id> --boards <board-id> -a aarch64 --rpms <pkg>
# sur la carte :
journalctl -u mender-updated -f                     # progression de l'update
sudo reboot                                         # OS : boot sur la nouvelle partition
./scripts/target/check.sh                           # part active + device type OK
```

> **État actuel** : le device est authentifié auprès de `community-mender.redpesk.bzh`
> et poll. Le déploiement factory fonctionne (`--rpms` requis). Voir
> `docs/mender-packaging-corn3.md` et, pour l'OTA locale (standalone),
> `docs/artefact-local.md`.

---

## 🖥 Simulation VM QEMU (optionnel, sans Mender).

Pour tester les scripts de provisionnement sans matériel supplémentaire, on
peut lancer une VM redpesk QEMU. **Limite à connaître** : les VMs sur ces
images ne peuvent PAS faire l'OTA Mender (même problème `mender-client`),
elles servent au test de l'outillage, pas à la démonstration finale.

```
./scripts/vm-fleet/launch-vm.sh 1      # VM #1, SSH port 3301
./scripts/vm-fleet/provision-vm.sh 1   # provisionnement partiel
```

Détails : `docs/simulate-fleet.md`.

---

## 🔒 Sécurité et limites.

- Les **clés privées Mender sont générées localement** (une par board) et stockées
  hors git (`.gitignore`). La confiance repose sur le modèle Mender : la factory
  connaît le hash de la clé publique de chaque board.
- Le device type Mender (`rpi3b-flotte`) est un element du modèle de confiance :
  un déploiement ne cible que des cartes du même device type (impossible de
  pousser une image prévue pour une autre plateforme).
- **Limites connues** :
  - l'image redpesk OS *pré-construite* ne gère pas l'OTA A/B d'origine (elle
    exige un partitionnement A/B compatible Mender). Le vrai bout-en-bout passe
    par une **image custom buildée dans la factory** (ou l'activation du support
    Mender au build redpesk).
  - **Mender** : le client s'installe via le repo **`redpesk-third-party`**
    (`echo 1 > /etc/dnf/vars/redpesk_third_party`) : `mender-client 5.0.3`,
    `mender-connect`, `mender-redpesk`. Le client atteint le serveur
    `community-mender.redpesk.bzh` ; reste à résoudre l'autorisation du device
    (`dev auth: unauthorized` malgré board préautorisée). Détail :
    `docs/mender-packaging-corn3.md`.

---

## 🐟 Build & audit sur la plateforme redpesk.

Le projet est industrialisé sur la **redpesk factory Community**
(`community-app.redpesk.bzh`, compte gratuit), via `rp-cli`. Résultats à
consolider au fil des builds (voir `docs/` et `redtests/`).

---

## 🧠 Zephyr dans redpesk (P5).

Preuve réussie : l'app `zephyr-hello-world` (sample Zephyr in-tree) est
buildée dans la **factory redpesk** (cible `qemu_x86_64`, distribution
`redpesk-zephyr-latest`, Zephyr 4.2.1) et s'exécute sous QEMU local :

```
*** Booting Zephyr OS build 4.2.1 ***
Hello World! qemu_x86_64/atom
```

Procédure complète + correction de la commande QEMU de la doc redpesk :
`docs/zephyr-qemu-demo.md`. Relance locale : `scripts/zephyr/test-local.sh`.

---

## 🔐 Secure boot ARM + Mender A/B sous Yocto (QEMU).

Image Yocto `meta-arm` `qemuarm64-secureboot` avec la chaîne **TF-A + OP-TEE +
U-Boot** (secure boot ARM) et un layout **Mender A/B** (4 partitions), buildée et
bootée en QEMU sans matériel :

```
TF-A (BL1 -> BL2 -> BL31) -> OP-TEE 4.1 -> U-Boot 2024.01 -> GRUB -> Linux 6.6.151
```

État A/B vérifié dans le guest : `mender_boot_part=2`, `upgrade_available=0`,
services `mender-updated` et `mender-authd` actifs, `/data` sur vda4.

Procédure + pièges : `docs/yocto-qemuarm64-secureboot-mender.md`. Relance :
`scripts/yocto/setup-build.sh`, puis `build.sh` et `boot-qemu.sh`.

---

## 🔁 OTA A/B, serveur self-hosted et flotte (QEMU).

- **OTA A/B** : `mender-update install` -> bascule de partition -> `commit`, ou
  `rollback` (explicite et automatique si le boot n'est pas committé).
- **Serveur Mender self-hosted** (Docker Compose, `mongo:7.0`) : auth device,
  inventaire, upload d'artefact, déploiement managed, statut `success`.
- **Flotte simulée** : 3 devices QEMU (MAC distinctes), groupe `flotte-qemu`,
  déploiement **par vagues** (1 device puis le groupe).

Détails, API et pièges : `docs/mender-server-selfhosted-et-flotte.md`. Démarrage
du serveur : `scripts/mender-server/up.sh`.

---

## 🌐 Note : WiFi RPi3B+ sur redpesk.

Constat et résolution au 09/09/2026 :
- Au départ, le WiFi **ne fonctionnait pas** sur le RPi3B+ sous redpesk corn 3.0
  (noyau 6.12) : `brcmfmac` chargeait mais `wlan0` restait DOWN (`NO-CARRIER`).
- **Résolu** : la radio scanne correctement ; le vrai blocage était la config
  réseau (interface non attachée à `wpa_supplicant`) + le psk hashé mal
  capturé. Depuis, le RPi3B+ se connecte en WiFi (wlan0 192.168.56.x) via
  `wpa_supplicant` + `systemd-networkd`, et tient au reboot.

Conséquence pour ce projet : la carte redpesk tourne en WiFi comme en Ethernet,
le wifi n'est pas requis pour la démo OTA Mender (elle passe en Ethernet/VLAN).

Détails du diagnostic (no txcap = log-noise, pas la cause) :
`docs/wifi-rpi3b-brcmfmac.md`.

---

## 📜 Licence.

Apache-2.0, 2026 Parad1gm_0xFF. Projet de démonstration, non affilié à IoT.bzh.
Les noms redpesk, Mender et Yocto restent la propriété de leurs détenteurs.
