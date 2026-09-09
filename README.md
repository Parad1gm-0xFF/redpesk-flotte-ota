# 🚚 redpesk-flotte-ota.

> Flotte de capteurs **Raspberry Pi 3B+** sous **redpesk OS**, provisionnée et
> mise à jour **en bout-en-bout** via la **redpesk factory** et son **OTA Mender**
> (A/B, rollback). Squelette de départ, fractionné du projet
> `secure-telemetry-node`.

Projet de démonstration pour un poste d'**Ingénieur Linux Embarqué
Kernel/BSP** (esprit candidature IoT.bzh, Lorient), aligné sur la plateforme
**redpesk** (factory, packaging RPM, sécurité dès le build, OTA).

---

## 🎯 Ce que le projet tente de prouver.

| Mission / compétence | Preuve dans ce dépôt |
|---|---|
| **OTA SOTA** (Software Over The Air) | Dossier `factory/` + `target/` : déploiement Mender sur une flotte RPi3B+ |
| **Gestion de flotte** redpesk factory | Scripts `rp-cli` : model board, boards, release, deploy |
| **Provisionnement cible** | Script `target/provision.sh` : préparation d'une carte neuve (flash, SSH, device type) |
| Packaging **RPM** | Specfile installant la configuration Mender et les redtests |
| **Tests** | `redtests/` : tests TAP sur cible (état OTA, services, device type) |
| **Sécurité** | Clés privées jamais commitées, identité board = MAC + clé (modèle Mender), device type strict |
| **Reproductibilité** | Dossier `config/` centralisé, un fichier par cible |

---

## 🏗 Architecture.

```
┌─────────────────────────────┐       ┌─────────────────────────────────┐
│  redpesk factory (.bzh)     │       │  Flotte cible (RPi3B+)          │
│   ├── project + app RPM     │       │   ├── redpesk OS (image)        │
│   ├── model board           │◄────► │   ├── mender-client (RPM)       │
│   ├── board (MAC + clé)     │ HTTPS │   ├── device type (Mender)      │
│   └── release + deploy OTA  │       │   └── config redpesk-config     │
└─────────────────────────────┘       └─────────────────────────────────┘
         │  rp-cli (poste dev)
         ▼
   scripts/factory/*.sh        scripts/target/*.sh (à exécuter sur carte)
```

- **Côté factory** : un projet redpesk contient l'application (le RPM de config)
  et l'image OS. Le model board définit le `device type` Mender, les boards sont
  les cartes physiques identifiées par **MAC** (et pré-autorisées).
- **Côté cible** : l'image redpesk OS embarque `mender-redpesk` + `mender-connect`
  (client OTA). Le provisionnement installe `redpesk-config` pointant vers la
  factory, définit le `device type`, et enregistre la clé privée de la board.
- **Déploiement** : un `release` du projet est déployé sur le model board depuis
  la factory ; Mender pousse l'update **A/B** sur les cartes, avec **rollback**
  automatique si le boot de la nouvelle partition échoue.

---

## 🗂 Arborescence.

```
config/                   → Configuration centralisée (factory URL, utilisateur, rp-cli)
factory/
  models-board.json       → Modèle de board (device type) pour la factory
  boards.csv              → Inventaire de la flotte (nom, MAC, notes)
scripts/
  factory/
    provision.sh          → Création model board + boards dans la factory (rp-cli)
    deploy.sh             → Release + déploiement OTA sur la flotte
    status.sh             → État des boards / déploiements (rp-cli)
  target/
    provision.sh          → Préparation d'une carte : flash, device type, config Mender
    check.sh              → Diagnostic sur cible : services, device type, part active
    rollback.sh           → Forcer le retour sur la partition précédente (A/B)
  vm-fleet/
    launch-vm.sh          → Démarre une board virtuelle (VM redpesk QEMU) de la flotte
redtests/                 → Tests TAP exécutés par la factory sur cible
spec/                     → Specfiles RPM (package de config + redtests)
docs/                     → Notes de conception, référence des commandes rp-cli
```

---

## ✅ Démonstration (bout-en-bout).

### 1. Prérequis (poste de dev).

```bash
# rp-cli configuré (voir docs/redpesk-cli.md) :
rp-cli onboard

# Une clé mender par board sera générée au provisionnement, jamais commitée.
```

### 2. Déclarer la flotte dans la factory.

```bash
cp config/.env.example config/.env   # renseigner FACTORY_URL, USER, …
./scripts/factory/provision.sh       # crée model board + boards (via rp-cli)
./scripts/factory/status.sh          # vérifie l'état
```

### 3. Provisionner une carte RPi3B+.

```bash
sudo ./scripts/target/provision.sh /dev/sdX     # flash image redpesk OS + config
ssh root@<ip>                                   # première connexion
```

Le script configure : `redpesk-config` (pointe vers la factory), le device type
(`rpi3b-flotte`), la clé privée Mender, et active `mender-authd` + `mender-updated`.

### 4. Vérifier que la carte est enregistrée.

```bash
./scripts/factory/status.sh                     # la board doit passer "pré-autorisée → acceptée"
```

### 5. Déployer une mise à jour OTA.

```bash
./scripts/factory/deploy.sh "<message de release>"   # build, release, deploy sur le model board
```

Sur la carte :

```bash
journalctl -u mender-updated -f                     # progression de l'update
sudo reboot                                         # boot sur la nouvelle partition
./scripts/target/check.sh                           # part active + device type OK
```

### 6. Rollback (partition A/B).

```bash
./scripts/target/rollback.sh                        # force le retour sur la partition précédente
reboot
```

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
    Mender au build redpesk) : c'est la phase suivante du projet.
  - les tests embarqués redpesk sur flotte restent soumis à la disponibilité de
    l'infrastructure Community (comme pour le projet initial).

---

## 🐟 Build & audit sur la plateforme redpesk.

Le projet est industrialisé sur la **redpesk factory Community**
(`community-app.redpesk.bzh`, compte gratuit), via `rp-cli`. Résultats à
consolider au fil des builds (voir `docs/` et `redtests/`).

---

## 🌐 Note : WiFi RPi3B+ sous redpesk corn 3.0.

Constat fait au 09/09/2026 : le **WiFi ne fonctionne pas** sur le RPi3B+ sous
redpesk corn 3.0 (noyau 6.12) : `brcmfmac` charge mais `wlan0` reste DOWN
(`NO-CARRIER`). La même carte + le même firmware fonctionnent sous Debian Trixie
(noyau 6.18.  Le maillon défaillant est le **pilote `brcmfmac` monolithique du
noyau 6.12** (Debian 6.18 utilise la version splitté bca/cyw/wcc).

Conséquence pour ce projet :
- la **carte redpesk** est utilisée en **Ethernet** (le WiFi n'est pas requis
  pour la démo OTA Mender) ;
- la **carte Debian** sert de connectivité maison (WiFi).

Détails et sources : `docs/wifi-rpi3b-brcmfmac.md`.

---

## 📜 Licence.

Apache-2.0, 2026 Parad1gm_0xFF. Projet de démonstration, non affilié à IoT.bzh.
Les noms redpesk, Mender et Yocto restent la propriété de leurs détenteurs.
