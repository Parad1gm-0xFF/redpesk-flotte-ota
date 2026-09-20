# Image Mender A/B construite localement (RPi 3B+).

Objectif : produire une image **Mender A/B** (dual-rootfs) sans passer par la
factory redpesk (dont le build d'image est indisponible en Community).

**Statut : image produite (20/09/2026).** Conversion réussie via
`mender-convert`.

## Méthode : mender-convert (Docker)

`mender-convert` convertit une image existante (Debian/Raspbian) en image
Mender A/B (partitionnement + intégration U-Boot + client Mender).

### Entrée
Raspberry Pi OS Lite **Trixie arm64** (`raspios_lite_arm64`, 64-bit).

### Config
`configs/raspberrypi/uboot/debian/raspberrypi3_bookworm_64bit_config`
(accepte Trixie : `RASPBERRYPI_OS_MIN_VERSION=12`).

### Commande (montages par sous-dossiers, PAS sur /mender-convert)

```
docker run --rm --privileged=true --cap-add=SYS_MODULE \
  -v $PWD/input:/mender-convert/input \
  -v $PWD/deploy:/mender-convert/deploy \
  -v $PWD/work:/mender-convert/work \
  -v $PWD/logs:/mender-convert/logs \
  -v /dev:/dev -v /lib/modules:/lib/modules:ro \
  --env MENDER_ARTIFACT_NAME=release-1 \
  mendersoftware/mender-convert:latest \
  --disk-image input/raspios-lite.img \
  --config configs/raspberrypi/uboot/debian/raspberrypi3_bookworm_64bit_config
```

> Piège : monter un dossier sur `/mender-convert` **masque** l'outil et
> l'entrypoint de l'image. Monter uniquement `input/`, `deploy/`, `work/`,
> `logs/` (cf. le wrapper officiel `docker-mender-convert`).

### Résultat (`deploy/`)
- `raspios-lite-raspberrypi3_64-mender.img` (8 GiB) — image disque A/B
- `raspios-lite-raspberrypi3_64-mender.mender` (765 Mo) — artefact Mender (MAJ OS)
- `.cfg`

Partitionnement obtenu (msdos) :
```
p1 boot     512 MiB  fat32   (démarrage)
p2 rootfs A 3764 MiB ext4
p3 rootfs B 3764 MiB ext4
p4 data     128 MiB  ext4
```

## Flashage et test A/B — VALIDÉ (20/09/2026)

1. Image flashée sur carte SD (`dd`, layout A/B vérifié).
2. Premier boot (rootfs A), accès préparé (`userconf.txt` + `ssh` sur la
   partition boot), WiFi configuré (`nmcli`).
3. **Test A/B standalone** :
   - `mender-update install raspios-lite-raspberrypi3_64-mender.mender`
     → écrit sur la partition **inactive (B)**, `Installed, but not committed`.
   - `reboot` → le device **boote sur B** (`findmnt /` = `/dev/mmcblk0p3`).
   - `commit` (après reboot : mounted root == env) → **commité**.
4. **Résultat** : `ArtifactName = release-1`, état `ArtifactCommit_Leave`,
   `upgrade_available=0` (env U-Boot), device stable sur B, joignable en WiFi
   (192.168.56.99) et Ethernet.

### Points appris

- **Sémantique Mender** : `commit` se fait **après le reboot** sur la nouvelle
  partition (sinon : « Mounted root does not match boot loader environment »).
- **Failover** : sans commit, le `bootcount` U-Boot (`bootlimit=1`) a
  automatiquement **rollbacké** vers A — l'A/B et le failover sont donc bien
  opérationnels.
- **Piège de l'A/B** : la nouvelle partition (B) est l'image **propre** (avant
  personnalisations WiFi/user/SSH). Pour y accéder après bascule, il faut
  personnaliser B avant reboot (ou baker les personnalisations dans l'image via
  un overlay mender-convert).
- Le client était en mode **managed** par défaut (Hosted Mender, jeton vide) ;
  passage en **standalone** (ServerURL/TenantToken vides) pour le test local.

## Notes
- `MENDER_DEVICE_TYPE="raspberrypi3_64"` (défini par la config).
- Pour un OTA **managed**, configurer le client (`mender-setup`) vers un serveur
  Mender et enregistrer le device (device type `raspberrypi3_64`).
- Cette image est **Debian/RPi OS** (indépendante de redpesk) : c'est le
  dual-rootfs Mender « classique ».