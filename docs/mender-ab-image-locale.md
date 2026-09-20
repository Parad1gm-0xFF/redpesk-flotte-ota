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

## Flashage et test A/B

1. Flasher `...-mender.img` sur carte SD (`bmaptool`/`dd`, root requis).
2. Booter le RPi.
3. **Test A/B en standalone** (sans serveur) :
   ```
   scp raspios-lite-raspberrypi3_64-mender.mender root@<ip>:/root/
   ssh root@<ip>
   mender-update install /root/raspios-lite-raspberrypi3_64-mender.mender
   mender-update commit        # ou rollback
   reboot
   mender-update show-artifact # -> release-1
   ```
   L'artefact s'écrit sur la partition racine **inactive** (B), puis le boot
   bascule dessus : c'est le vrai **A/B** (à l'inverse de la mise à jour
   applicative RPM).

## Notes
- `MENDER_DEVICE_TYPE="raspberrypi3_64"` (défini par la config).
- Pour un OTA **managed**, configurer le client (`mender-setup`) vers un serveur
  Mender et enregistrer le device (device type `raspberrypi3_64`).
- Cette image est **Debian/RPi OS** (indépendante de redpesk) : c'est le
  dual-rootfs Mender « classique ».