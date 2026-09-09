# WiFi RPi3B+ sous redpesk corn 3.0 : constat et résolution.

## Constat (09/09/2026)

Le WiFi est **non fonctionnel** sur un RPi3B+ sous `redpesk Linux corn 3.0`
(noyau `6.12.25-13.bsp.rpi.rpcorn.aarch64`, image minimale) :

```
brcmfmac: brcmf_fw_alloc_request: using brcm/brcmfmac43455-sdio for chip BCM4345/6
brcmfmac: brcmfmac ... Firmware: BCM4345/6 wl0: ... version 7.45.265 (28bca26 CY)
brcmfmac: brcmf_c_process_txcap_blob: no txcap_blob available (err=-2)   # log-noise
$ ip -br link   → wlan0 DOWN (NO-CARRIER)
$ nmcli device status → wlan0 unmanaged
$ nmcli device wifi connect ... → "No Wi-Fi device found"
```

Le même RPi3B+ avec la **carte SD Debian officielle (Trixie, noyau 6.18)**,
mêmes fichiers `/lib/firmware/brcm/` → **WiFi fonctionnel**.

## Analyse

1. `no txcap_blob` / `no clm_blob` : **log-noise** (patch kernel 2026,
   mainteneurs : « end-users constantly misinterpret them »). Pas la cause.
2. Le fichier `.txt` (fix du bugzilla Red Hat 2256222) a été installé, sans effet.
3. Le facteur différenciant réel : **la version du pilote**.
   - redpesk 6.12 : pilote `brcmfmac` **monolithique** (un seul `.ko`)
   - Debian 6.18 : pilote **splitté** `brcmfmac-{bca,wcc,cyw}`
   - Des régressions WiFi BCM4345/6 liées à cette transition sont signalées
     chez Manjaro (« WiFi stops working with kernel newer than 6.9 ») et
     d'autres distros.

## Action retenue

- Carte **Debian** = WiFi maison (besoin immédiat).
- Carte **redpesk** = démo OTA Mender en **Ethernet**.
- Backport du pilote splitté Debian (6.18) vers 6.12 : non retenu
  (binaires `.ko` incompatibles noyau, travail long, risque élevé).

## Si nécessaire un jour

- Tester une redpesk à noyau ≥ 6.18 quand disponible.
- Re-tester le WiFi sur une image custom buildée (driver + firmware BSP).

## Références

- docs.redpesk.bzh : QEMU / boards / images
- bugzilla.redhat.com/2256222 : brcmfmac43455-sdio, `.txt`, wlan0
- LKML (mars 2026) : « wifi: brcmfmac: silence warning for non-existent,
  optional firmware » (txcap/clm = log-noise)
- forum Manjaro : WiFi broken with kernel ≥ 6.9 (BCM4345)