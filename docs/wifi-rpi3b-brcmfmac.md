# WiFi RPi3B+ sous redpesk corn 3.0 : diagnostic et résolution.

> **Statut : RÉSOLU (13/09/2026).** Le WiFi fonctionne sous redpesk corn 3.0.
> Cause réelle : configuration réseau (pas le firmware ni le pilote).

## Solution retenue (mode station/client)

Pour connecter le RPi3B+ à un WiFi **existant** (réseau maison `JF56-Perso`) :

1. Installer `wpa_supplicant` (`dnf install wpa_supplicant`)
2. Renseigner `/etc/sysconfig/wpa_supplicant` : `INTERFACES="-iwlan0"`
   (sans ça, le service démarre en mode DBus `-u` **sans attacher l'interface** :
   c'est CE point qui bloquait tout)
3. Config WPA avec le **psk hashé** (`wpa_passphrase`, prendre la ligne `psk=`
   non commentée) dans `/etc/wpa_supplicant/wpa_supplicant.conf`
4. `wlan0` gérée par `systemd-networkd` (`/etc/systemd/network/10-wlan0.network`,
   DHCP) + device type posé
5. Redémarrer `wpa_supplicant` + `systemd-networkd`

Résultat : `wlan0` monte, s'associe (WPA), prend une IP DHCP, tient au reboot.

## Ne pas confondre avec le `wifiap-binding` (mode AP)

La doc redpesk a un composant dédié WiFi : **`wifiap-binding`**
(`docs.redpesk.bzh .../redpesk-core/wifiap-binding/`). Attention, ce n'est PAS
l'outil pour se connecter à un WiFi existant :

| | `wifiap-binding` | notre solution |
|---|---|---|
| Rôle | **Access Point** (la carte émet un WiFi) | **Station/client** (la carte se connecte) |
| Outils | `hostapd` + `dnsmasq` | `wpa_supplicant` + `systemd-networkd` |
| Cas | mode recovery redpesk, borne | connecter la carte au WiFi maison |

`hostapd` ne gère pas le mode client : le `wifiap-binding` n'aurait pas résolu
notre besoin (voir `docs/redpesk-services.md`).

## Diagnostic (historique, 09/09)

Le WiFi était **non fonctionnel** au départ sous `redpesk Linux corn 3.0`
(noyau `6.12.25-13.bsp.rpi.rpcorn.aarch64`, image minimale) :

```
brcmfmac: brcmf_fw_alloc_request: using brcm/brcmfmac43455-sdio for chip BCM4345/6
brcmfmac: Firmware: BCM4345/6 wl0: ... version 7.45.265 (28bca26 CY)
brcmfmac: brcmf_c_process_txcap_blob: no txcap_blob available (err=-2)   # log-noise
$ ip -br link   → wlan0 DOWN (NO-CARRIER)
$ nmcli device status → wlan0 unmanaged
$ nmcli device wifi connect ... → "No Wi-Fi device found"
```

Le même RPi3B+ avec la carte SD Debian (Trixie, noyau 6.18), mêmes fichiers
`/lib/firmware/brcm/` → WiFi fonctionnel.

### Fausses pistes écartées

1. `no txcap_blob` / `no clm_blob` : **log-noise** (patch kernel 2026,
   mainteneurs : « end-users constantly misinterpret them »). Pas la cause.
2. Le fichier `.txt` (fix bugzilla Red Hat 2256222) installé, sans effet seul.
3. Hypothèse « pilote 6.12 monolithique vs 6.18 splitté » : plausible mais
   **non déterminante** — la radio scannait déjà (`iw dev wlan0 scan` listait
   les AP). Le vrai blocage était la **config NetworkManager/wpa_supplicant**.
4. `nmcli device set wlan0 managed yes` : nécessaire mais insuffisant.

### Preuve que la radio fonctionnait

```
$ iw dev wlan0 scan
    SSID: JF56-Perso       (freq 2462, signal -80)
    SSID: JF56-Invités
```

## Références

- docs.redpesk.bzh : QEMU / boards / images ; `docs/redpesk-core/` (bindings)
- bugzilla.redhat.com/2256222 : brcmfmac43455-sdio, `.txt`, wlan0
- LKML (mars 2026) : « wifi: brcmfmac: silence warning for non-existent,
  optional firmware » (txcap/clm = log-noise)