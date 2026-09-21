# OTA A/B et flotte simulée sous QEMU (Mender self-hosted).

Objectif : démontrer, sans matériel, l'**OTA A/B** (bascule, commit, rollback),
un **serveur Mender self-hosted** (auth, inventaire, déploiement managed) et une
**flotte simulée** (plusieurs devices, groupes, déploiement par vagues).
**Statut : validé (21/09/2026).**

Base : image Yocto `qemuarm64-secureboot` (TF-A + OP-TEE + U-Boot) + Mender A/B,
voir `docs/yocto-qemuarm64-secureboot-mender.md`.

## 1. OTA A/B en standalone (QEMU)

L'artefact est servi en HTTP à l'invité (`python3 -m http.server` sur l'hôte,
joignable via `10.0.2.2`), puis installé par `mender-update` :

```
mender-update install http://10.0.2.2:8000/release-2.mender
# -> "Installed, but not committed." puis reboot
mender-update commit        # ou mender-update rollback
```

Résultats observés (env GRUB `/boot/efi/grub-mender-grubenv/mender_grubenv1/env`) :

| Étape | `mender_boot_part` | `upgrade_available` | `root=` |
|---|---|---|---|
| avant | 2 | 0 | vda2 |
| après install | 3 | 1 | (vda2) |
| après reboot | 3 | 1 | **vda3** |
| après commit | 3 | 0 | vda3 |

**Rollback explicite** : réinstaller puis `mender-update rollback` -> retour à la
partition précédente (`mender_boot_part=3`, `upgrade_available=0`).

**Rollback automatique** : installer puis rebooter **sans commit** -> au boot
suivant, l'intégration GRUB (`90_mender_boot_grub.cfg`, bootcount) revient sur la
partition committée (`root=/dev/vda3`, `upgrade_available=0`).

**Nouveau contenu** : un marqueur gravé dans l'image (`/etc/release-marker`)
passe de `release-2` à `release-3` (etc.) après l'update, ce qui prouve que le
nouveau rootfs est bien celui qui tourne.

## 2. Serveur Mender self-hosted (Docker)

Procédure officielle (`docs.mender.io/server-installation/evaluation-with-docker-compose`) :

```
git clone -b v4.1.0 https://github.com/mendersoftware/mender-server.git
cd mender-server
MONGO_VERSION=7.0 MENDER_IMAGE_TAG=v4.1.0 docker compose up -d
docker compose run --rm --no-deps useradm create-user \
    --username admin@docker.mender.io --password '...'
```

API de gestion : `https://docker.mender.io` (traefik). En l'absence d'entrée
`/etc/hosts`, l'hôte utilise `curl --resolve docker.mender.io:443:127.0.0.1`.

Points clés de l'API (v4.1.0) :

| Action | Endpoint |
|---|---|
| Login admin (JWT) | `POST /api/management/v1/useradm/auth/login` |
| Devices | `GET /api/management/v2/devauth/devices` |
| Accepter un auth set | `PUT /api/management/v2/devauth/devices/{id}/auth/{aid}/status` |
| Groupe d'un device | `PUT /api/management/v1/inventory/devices/{id}/group` |
| Upload artefact | `POST /api/management/v1/deployments/artifacts` (multipart) |
| Déploiement (devices) | `POST /api/management/v1/deployments/deployments` |
| Déploiement (groupe) | `POST /api/management/v1/deployments/deployments/group/{nom}` |

Le client invité est configuré (`/etc/mender/mender.conf`) avec
`ServerURL=https://docker.mender.io`, `ServerCertificate=/etc/mender/mender.crt`
(CA démo) et des intervalles de poll courts (10 s).

Résultat validé : device accepté -> inventaire soumis (`artifact_name`,
`device_type`) -> artefact `release-7` déployé -> bascule A/B -> **commit** ->
côté serveur `finished`, `success: 1`.

## 3. Flotte simulée (3 devices QEMU)

Trois instances QEMU, une copie de disque chacune, **MAC distincte** et console
série sur un port distinct :

```
qemu-system-aarch64 ... -device virtio-net-pci,netdev=net0,mac=52:54:00:12:34:0N \
    -netdev user,id=net0 -serial telnet:127.0.0.1:444N,server,nowait ...
```

Chaque device régénère sa clé (`rm /data/mender/mender-agent.pem` puis restart du
client) pour avoir une identité propre, puis est accepté côté serveur.

Déploiement **par vagues** :

| Vague | Cible | Résultat serveur |
|---|---|---|
| 1 | 1 device | `finished`, `success: 1` |
| 2 | groupe `flotte-qemu` | `finished`, `success: 2`, `already-installed: 1` |

Après la vague 2, les 3 devices sont en `release-8` (marqueurs invités et
inventaire serveur concordants), et le groupe `flotte-qemu` contient 3 devices.

## Pièges rencontrés et corrections

1. **`mongo:8.0` ne démarre pas sur kernel >= 6.19** (TCMalloc vendu,
   SERVER-121912) : « MongoDB cannot start: Linux kernel versions 6.19 and newer
   has a known incompatibility ». Solution : `MONGO_VERSION=7.0`.
2. **La config serveur du device doit être dans l'image** : `/etc/hosts`
   (résolution de `docker.mender.io`), la CA démo (`/etc/mender/mender.crt`) et
   `mender.conf` ajoutés à la main **ne survivent pas** à un update A/B. Le
   rootfs qui tourne doit déjà les avoir pour rapporter/committer : les graver
   dans l'image (postprocess).
3. **Changer le corps d'une fonction dans un `.inc` requis ne change pas la
   signature de `do_rootfs`** (la variable `ROOTFS_POSTPROCESS_COMMAND` reste
   identique) : forcer `bitbake -f -c rootfs`.
4. **Overlays qcow2** : le fichier de base ne peut pas servir de backing à
   plusieurs QEMU (verrou d'écriture). Utiliser une copie complète par device.
5. **Console série telnet** : une reconnexion ne réaffiche pas l'invite de login
   (déjà consommée) ; envoyer un retour ligne pour la forcer.
6. **Stockage** : MongoDB + images Docker sont volumineux ; le stockage Docker
   est déplacé sur le T7 (`/mnt/yocto/docker-storage`, `RequiresMountsFor`).

## Lien avec redpesk

Ces démos couvrent les briques visées par la candidature : OTA A/B avec
rollback, intégration serveur (auth, inventaire, déploiement), et gestion de
flotte (groupes, déploiement par vagues), sans dépendre de la factory Community
ni d'un serveur externe.
