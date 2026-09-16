# OTA locale : créer/déployer un artefact Mender sans la factory.

Objectif : contourner le bug de la factory (`POST /deployments`,
`create_artifact` → `AttributeError: datetime.time has no attribute 'sleep'`)
en créant et déployant un artefact Mender **localement**.

**Statut : validé (16/09/2026)** sur le RPi3B+ (device type
`rpi3b-flotte_91c8e506`) : artefact créé hors factory, installé en mode
standalone, commité.

## Outillage (sans sudo)

`mender-artifact` et `mender-cli` sont fournis par l'image Docker officielle :

```
docker run --rm mendersoftware/mender-ci-tools:master mender-artifact --version
# mender-artifact version 4.4.1
docker run --rm mendersoftware/mender-ci-tools:master mender-cli --version
# mender-cli version 2.0.0
```

(Le tag `latest` n'existe pas ; utiliser `master`. L'image est aussi dispo via
le repo APT Mender `downloads.mender.io/repos/workstation-tools`.)

## Modules de mise à jour du client redpesk

Sur la cible : `/usr/share/mender/modules/v3/` →
`directory`, `redpesk-payload`, `rootfs-image`, `single-file`.

- `single-file` : dépose **un fichier** à un emplacement donné (démo simple).
- `redpesk-payload` : attend un `update.tar` de RPM (c'est ce que produit
  `make-mender-artifact -p rpm-os` côté redpesk). Pour un vrai déploiement RPM.

## Procédure (module single-file)

Structure du payload (4 fichiers) : `dest_dir`, `filename`, `permissions`,
et le fichier à déployer.

```
mkdir -p payload && cd payload
printf '/root' > dest_dir
printf 'ota-demo.txt' > filename
printf '0644' > permissions
printf 'Hello OTA local\n' > ota-demo.txt
```

Création de l'artefact (**un `-f` par fichier** ; c'est ce que fait le script
officiel `single-file-artifact-gen`) :

```
docker run --rm -v "$PWD":/payload -v "$PWD/../out":/out \
  mendersoftware/mender-ci-tools:master mender-artifact write module-image \
  -T single-file \
  -t rpi3b-flotte_91c8e506 \
  -o /out/ota-demo-1.0.mender -n ota-demo-1.0 \
  -f /payload/dest_dir -f /payload/filename \
  -f /payload/permissions -f /payload/ota-demo.txt
```

> `-t` = device type cible (**doit** correspondre au device_type de la factory :
> `<model_name>_<model_id>`, ici `rpi3b-flotte_91c8e506`).

Déploiement en **mode standalone** sur la cible (aucun serveur requis) :

```
scp ota-demo-1.0.mender root@<ip>:/root/
ssh root@<ip>
mender-update install /root/ota-demo-1.0.mender
mender-update commit        # ou rollback
mender-update show-artifact # -> ota-demo-1.0
```

Sortie observée :

```
Installing artifact...
Installed, but not committed.
Use 'commit' to update, or 'rollback' to roll back the update.
...
Committed.
```

Le fichier `/root/ota-demo.txt` est bien présent. La mécanique OTA
(install/commit/rollback) est donc **pleinement démontrée localement**.

## Déploiement via serveur (managed) — reste à faire

Pour pousser un artefact depuis le serveur Mender de la factory
(`community-mender.redpesk.bzh`), utiliser `mender-cli` :

```
mender-cli login --server https://community-mender.redpesk.bzh --username <user>
mender-cli artifacts upload ota-demo-1.0.mender
```

Réserve : nécessite des **identifiants** sur ce serveur Mender (à confirmer
côté redpesk). C'est une alternative au déploiement factory (actuellement
cassé).

## Pour de vrais paquets RPM (redpesk-payload) — VALIDÉ

Le module `redpesk-payload` (type `rpm-os`) installe des RPM. Format attendu :

- un fichier `metadata` : `VERSION=2` + `PAYLOAD_TYPE="rpm-os"`
- le(s) RPM, signés (voir ci-dessous)

Création de l'artefact :

```
mender-artifact write module-image -T redpesk-payload \
  -t rpi3b-flotte_91c8e506 \
  -o /out/stn-payload-1.0.mender -n stn-payload-1.0 \
  -f /payload/metadata -f /payload/<paquet>.aarch64.rpm
```

Déploiement standalone observé (RPM `secure-telemetry-node` signé) :

```
Payload is of RPM type
Verifying packages...
Preparing packages...
secure-telemetry-node-0.1.0-1.el9.aarch64
RPM successfully installed!
Installed and committed.
$ rpm -q secure-telemetry-node
secure-telemetry-node-0.1.0-1.el9.aarch64
```

### Deux barrières réelles rencontrées

1. **Conflit de dépendances** : la carte avait `secure-telemetry-node` + son
   `-redtest` (dépend de la version exacte). `rpm -U` du nouveau paquet casse
   cette dépendance → retirer le paquet conflictuel avant (`dnf remove`).
2. **Signature obligatoire** : le module exécute
   `rpm --define='%_pkgverify_level all' -U --force`, donc le RPM **doit être
   signé** (sinon « does not verify: no signature »). Procédure :
   - générer une clé GPG, signer le RPM (`rpm --addsign`),
   - importer la clé publique sur la cible (`rpm --import pub.asc`),
   - puis déployer.

Cela confirme que redpesk **impose des paquets signés** pour l'OTA (cohérent
avec « GPG check enabled by default » des notes factory).

Reproduire : `scripts/ota-local/build-rpm-artifact.sh <rpm> <device_type>`.

## Déploiement managed (mender-cli) — serveur joignable, identifiants requis

Le serveur Mender de la factory est **joignable** :

```
$ curl -sI https://community-mender.redpesk.bzh            -> HTTP 301
$ curl -s -X POST .../api/management/v1/useradm/auth/login -> HTTP 401 (auth requise)
```

Upload d'artefact via `mender-cli` :

```
mender-cli login --server https://community-mender.redpesk.bzh --username <user>
mender-cli artifacts upload ota-demo-1.0.mender
```

**Blocage** : nécessite des **identifiants** sur `community-mender.redpesk.bzh`
(login interactif). Non disponibles. À demander à redpesk (le compte factory
`community-app.redpesk.bzh` ne donne pas forcément accès à l'API Mender).

Si obtenus, cette voie permettrait un déploiement **managed** de bout en bout
sans l'endpoint factory cassé.

## Reproduire

- `scripts/ota-local/build-artifact.sh` : artefact `single-file` (démo).
- `scripts/ota-local/build-rpm-artifact.sh` : artefact `redpesk-payload` (RPM).