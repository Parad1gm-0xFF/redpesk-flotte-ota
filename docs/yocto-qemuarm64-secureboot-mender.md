# Yocto qemuarm64-secureboot + secure boot ARM + Mender A/B (démonstration).

Objectif : construire et booter, **sans matériel**, une image Yocto pour
`qemuarm64-secureboot` avec la chaîne **TF-A + OP-TEE + U-Boot** (secure boot
ARM) et un layout **Mender A/B**.
**Statut : validé (21/09/2026).**

## Principe

- BSP `meta-arm` `qemuarm64-secureboot` : QEMU `virt,secure=on`, firmware
  `flash.bin` = TF-A (BL1/BL2/BL31) + U-Boot, noyau chargé par U-Boot puis GRUB
  depuis l'ESP.
- `meta-mender` (`mender-full`) : image A/B (4 partitions), client Mender,
  artefact OTA.
- Session Yocto : poky `scarthgap`.

## Prérequis

- Hôte Linux (testé Ubuntu 26.04, non validé par Yocto), ~50 Go libres, git et
  les paquets Yocto usuels.
- Racine de build sur un système de fichiers **avec symlinks et sockets Unix** :
  pas d'exFAT (utiliser de l'ext4, éventuellement une image loop montée).

## Partitions de l'image Mender (`uefiimg`)

| Partition | Taille | Rôle |
|---|---|---|
| vda1 | 64 Mo | ESP (FAT) : GRUB, noyau `Image`, dtb, env Mender |
| vda2 | 408 Mo | rootfs A (active) |
| vda3 | 408 Mo | rootfs B (inactive) |
| vda4 | 128 Mo | data persistant (`/data`) |

## Procédure

```
# 1. Sources + configuration + contournements (idempotent)
scripts/yocto/setup-build.sh /mnt/yocto

# 2. Build (image + artefact OTA)
scripts/yocto/build.sh /mnt/yocto

# 3. Boot en QEMU (console série telnet 127.0.0.1:4444, login root, mdp vide)
scripts/yocto/boot-qemu.sh /mnt/yocto
```

## Résultats

Chaîne de boot (console série) :

```
NOTICE:  BL1: v2.10.4(release)
NOTICE:  BL1: Booting BL2
NOTICE:  BL2: v2.10.4(release)
NOTICE:  BL1: Booting BL31
U-Boot 2024.01
[    1.94] optee: revision 4.1 (18b424c2)
[    0.00] Kernel command line: BOOT_IMAGE=/boot/Image root=/dev/vda2
[    0.00] Linux version 6.6.151-yocto-standard
```

Soit **TF-A (BL1 -> BL2 -> BL31) -> OP-TEE 4.1 -> U-Boot 2024.01 -> GRUB ->
Linux 6.6.151**.

Layout Mender et état A/B (console invité) :

```
# cat /proc/partitions                     -> vda1 vda2 vda3 vda4
# mount                                    -> / sur vda2, /boot/efi (vfat) sur vda1, /data sur vda4
# systemctl is-active mender-updated mender-authd   -> active / active
# cat /boot/efi/grub-mender-grubenv/mender_grubenv1/env
bootcount=0
mender_boot_part=2
upgrade_available=0
```

`mender_boot_part=2` = rootfs A active, `upgrade_available=0` = pas de mise à
jour en attente. L'env est dupliqué (`mender_grubenv1` et `mender_grubenv2`)
avec un `lock` vérifié par `sha256sum` (redondance Mender).

Artefacts produits dans `tmp/deploy/images/qemuarm64-secureboot/` :

| Fichier | Rôle |
|---|---|
| `.uefiimg` (~1 Go) | disque complet 4 partitions (A/B) |
| `.mender` (~34 Mo) | artefact OTA, nom `release-1` |
| `.wic.qcow2` (~120 Mo) | image meta-arm (2 partitions, **pas** le layout A/B) |

## Pièges rencontrés et corrections

1. **exFAT** (SSD externe) : pas de sockets Unix (bitbake échoue) ni de
   symlinks (clone cassé). Solution : image ext4 loop montée comme racine de
   build.
2. **Symlinks cassés après clone** : `git config core.symlinks true` puis
   `git reset --hard` sur chaque dépôt.
3. **`mender-systemd`** : requiert `INIT_MANAGER = "systemd"`.
4. **`kernel-devicetree`** : QEMU fournit son DTB à U-Boot, le paquet manque ->
   `MACHINE_ESSENTIAL_EXTRA_RDEPENDS:remove = "kernel-devicetree"`.
5. **Intercepts qemu-user** : sur Ubuntu 26.04, les intercepts postinst qui
   passent par qemu-user échouent (exit 1 silencieux). Ils ne font que
   pré-générer des caches (fonts, gio, pixbuf, udev, gtk, mime, desktop) ->
   neutralisés, régénérés au premier boot. **À corriger (qemuwrapper) pour une
   image de production.**
6. **`MENDER_BOOT_PART_SIZE_MB`** : défaut 16 Mo, insuffisant pour le noyau
   arm64 `Image` (~25 Mo) -> `Disk full` à la création de la partition boot.
   Passer à 64 Mo.
7. **Disque QEMU** : QEMU `virt` expose le disque en `/dev/vda`, Mender attend
   `/dev/mmcblk0` par défaut -> `MENDER_STORAGE_DEVICE = "/dev/vda"`, sinon
   `emergency mode` (attente de `/dev/mmcblk0p4`).
8. **Image à booter** : le `wic.qcow2` de meta-arm n'a que 2 partitions (pas de
   `/data`) -> booter l'**`uefiimg`** converti en qcow2.

## Lien avec redpesk

Cette démo prouve, sur un BSP ARM sans carte physique, la chaîne **secure boot
ARM** et l'**OTA A/B Mender**, en complément de la démo **UEFI Secure Boot x86**
(`docs/uefi-secureboot-qemu.md`). C'est un secure boot **émulé** (clés
logicielles) : la racine de confiance matérielle (eFuses, HAB) n'est pas
émulable, une vraie carte reste nécessaire pour la garantir.