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

## Image custom RPi (factory, mkosi) : BLOQUÉE par l'édition Community

L'image a été créée correctement, mais le build est **annulé** par la factory
Community (`canceled`, sans aucun log → annulation au niveau infra).

Cause confirmée par la doc officielle « Community edition »
(`getting_started/docs/community-edition.html`) :

- **Feature limitation** : « Local builder : image build is not available ».
- **Ressources partagées** : « internal factory resources are shared between
  users based on waiting queues, meaning **restricted parallel builds and
  hardware resources usage (CPU, RAM, …)** ».
- Quotas : 10 projets, 100 apps, **3 images** max ; 10 Go.

→ Les builds d'image ne sont **pas garantis** en Community (best-effort sur
builder partagé) ; le nôtre a été annulé. Les images visibles sur le compte
sont d'ailleurs toutes `iotbzh (external)` (pré-construites), aucune buildée
par l'utilisateur.

### Config créée (pour référence)

```
rp-cli projects add -n custom-images --images \
    --mandatory-arch aarch64 --mandatory-distro redpesk-lts-corn-3.0-update
rp-cli images add -n rpi-custom --arch aarch64 \
    -d redpesk-lts-corn-3.0-update -p custom-images \
    --build-type mkosi \
    --mkosi-url https://github.com/redpesk-infra/rp-mkosi.git \
    --mkosi-branch corn-3.0-update --mkosi-file mkosi-rpi.conf \
    --mkosi-profiles smack,minimal,localrepo \
    --mkosi-pkgs mender-client,mender-connect,mender-redpesk,jq,chrony
rp-cli images build rpi-custom --nonblocking   # -> canceled
```

## Alternatives (hors factory Community)

1. **Retenter** le build (file partagée) — non garanti.
2. **Démontrer l'A/B redpesk (recovery) sur la carte existante** : l'image
   pré-construite contient déjà RECOVERY/ROOT/DATA → tester le failover
   (échecs de boot → restauration depuis `/recovery/backup.tar.gz`). C'est
   l'A/B redpesk réel, sans image custom.
3. **Image Mender A/B en local** (Yocto `meta-mender`, ou `mender-convert`),
   indépendamment de redpesk — c'est le dual-rootfs Mender « classique ».
4. **Demander à redpesk** de relever les limites Community, ou un accès Pro
   (SaaS/on-prem) pour builder l'image.

## Marche à suivre quand une image sera disponible

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