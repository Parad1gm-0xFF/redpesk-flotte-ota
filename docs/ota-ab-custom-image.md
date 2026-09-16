# OTA A/B via image custom (RPi) : mécanisme et état.

## Ce que « A/B » signifie chez redpesk

Ce n'est **pas** l'A/B symétrique de Mender (deux rootfs). C'est un design
**A' (recovery) + B (root)** :

- Partitions (`redpesk-infra/rp-mkosi`, `repart.d/common`) :
  `CONFIG`, **`RECOVERY`** (500 Mo, montée `/recovery`), `ROOT`, `DATA`.
- `/recovery` contient un `backup.tar.gz` (archive de la rootfs), le kernel
  (`recovery.img`), le(s) dtb et un `initramfs.img`.
- En cas d'échec de boot répété, U-Boot (`bootcount` limit, aarch64) ou GRUB
  (x86) démarre le **mode recovery**, qui **restaure** la partition `ROOT` à
  partir de `backup.tar.gz`.
- Cette disposition est **déjà présente dans les images pré-construites**
  (on observe les partitions RECOVERY/ROOT/DATA).

Conséquence : l'OTA redpesk est **basée paquets (RPM)** (module
`redpesk-payload` : `rpm-os`, `rpm-dir`, …) ; l'« A/B » est le **failover
recovery**. Une image custom sert à **intégrer nos outils/apps** et la config,
pas à changer le modèle A/B.

Sources : docs.redpesk.bzh (recovery/1-recovery-architecture),
github.com/redpesk-infra/rp-mkosi (repart.d/common).

## Image custom RPi (factory, mkosi) : créée, build en attente

Créée via `rp-cli` (sans forker rp-mkosi, en ajoutant des paquets à la volée) :

```
rp-cli projects add -n custom-images --images \
    --mandatory-arch aarch64 --mandatory-distro redpesk-lts-corn-3.0-update

rp-cli images add -n rpi-custom --arch aarch64 \
    -d redpesk-lts-corn-3.0-update -p custom-images \
    --build-type mkosi \
    --mkosi-url https://github.com/redpesk-infra/rp-mkosi.git \
    --mkosi-branch corn-3.0-update \
    --mkosi-file mkosi-rpi.conf \
    --mkosi-profiles smack,minimal,localrepo \
    --mkosi-pkgs mender-client,mender-connect,mender-redpesk,jq,chrony

rp-cli images build rpi-custom --nonblocking   # build 55097
```

Config d'image confirmée (`rp-cli images get rpi-custom -v`). Mais le build
**reste en file** (statut `free`) après plusieurs minutes : vraisemblablement
une limite de capacité du compte **Community** (comme les tests embarqués QEMU
bloqués auparavant), ou une restriction des builds d'image sur compte gratuit.

À retenter, ou à remonter au support (déjà contacté pour d'autres points).

## Marche à suivre quand le build aboutira

1. Télécharger l'image (`rp-cli images get rpi-custom -v` → Download URL, ou
   `rp-cli images builds download`).
2. Flasher sur carte SD (bmaptool/dd) et booter le RPi.
3. Vérifier la présence de `mender-client`, `jq`, `chrony` (intégrés).
4. Tester :
   - OTA **applicative** (factory `project-releases deploy --rpms`) ;
   - **failover recovery** : provoquer des échecs de boot (U-Boot `bootcount`)
     et vérifier la restauration de `ROOT` depuis `/recovery/backup.tar.gz`.

## Notes matérielles / opérationnelles

- `jq` et `chrony` posés sur la carte de référence (inventaire Mender propre,
  heure synchronisée `System clock synchronized: yes`).
- L'image pré-construite suffit pour l'OTA applicative ; l'image custom viserait
  l'intégration « à froid » (outils + apps dans l'image).