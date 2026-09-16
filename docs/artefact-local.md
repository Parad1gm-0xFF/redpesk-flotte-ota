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

## Pour de vrais paquets RPM (redpesk-payload)

Le module `redpesk-payload` attend, dans l'artefact, un `update.tar` contenant
les RPM, plus un fichier `metadata`. C'est le format produit par
`make-mender-artifact -p rpm-os` (redpesk local builder). À reproduire pour un
déploiement de paquets réel via Mender (hors bug factory).

## Reproduire

Voir `scripts/ota-local/build-artifact.sh` (création de l'artefact de démo).