# redpesk core : APIs & services (bindings AFB).

Redpesk n'est pas seulement une **factory** + un **OS** : c'est aussi une couche
de **microservices**, exposés comme **bindings AFB** (Application Framework
Binder), avec des APIs REST/Websocket. Source : `docs.redpesk.bzh` →
`redpesk-core/docs/services-list.html` (+ dépôts `github.com/redpesk-*`).

## Liste des services

| Service | Domaine | Rôle | Sources |
|---|---|---|---|
| `afb-librust` | Common | API Rust native pour développer des bindings AFB (compatibles C/C++) | redpesk-common/afb-librust |
| `canbus-binding` | Common | Service CAN bas niveau (encode/decode CAN) | redpesk-common/canbus-binding |
| `canopen-binding` | Industrial | Contrôle d'un réseau CANopen (basé sur Lely) | redpesk-industrial/canopen-binding |
| `modbus-binding` | Industrial | Modbus TCP + conversion de formats | redpesk-common/modbus-binding |
| `gps-binding` | Common | Position GPS depuis un device physique | redpesk-common/gps-binding |
| `helloworld-binding` | Samples | Exemple de binding en contexte redpesk | redpesk-samples/helloworld-binding |
| `platform-info-binding` | Common | Infos système via JSON | redpesk-common/platform-info-binding |
| `sec-gate-oidc` | Common | Extension afb-binder-v4 : auth via IDP externe (OIDC) | redpesk-common/sec-gate-oidc |
| `secure-storage-binding` | Addons | Stockage sécurisé (API compatible legato) | redpesk-addons/secure-storage-binding |
| `spawn-binding` | Common | Lance scripts/binaires de façon sécurisée | redpesk-common/spawn-binding |
| `redpak-binding` | Labs | Gestion des conteneurs Rednode sur cible | redpesk-labs/redpak-binding |
| `wifiap-binding` | Common | **WiFi Access Point** (hostapd + dnsmasq) | redpesk-common/wifiap-binding |

Domaines : Common, Industrial, Marine, Addons, Labs, Samples.

## Pertinence pour ce projet / la candidature IoT.bzh

- **`afb-librust`** : écrire un binding AFB en **Rust** ferait le lien direct
  avec `secure-telemetry-node` (Rust + sécurité). Piste forte.
- **`spawn-binding`** : exécution sécurisée de binaires/scripts — résonne avec
  le travail seccomp/self-test du projet initial.
- **`secure-storage-binding`** / **`sec-gate-oidc`** : briques cybersécurité.
- **`wifiap-binding`** : à ne pas confondre avec un client WiFi ; c'est le mode
  **AP** (borne), utilisé par le mode recovery redpesk.
- **`canbus` / `canopen` / `modbus`** : débouchés industriels (automotive,
  énergie) où redpesk se positionne.

## À ne pas confondre : `wifiap-binding` vs client WiFi

- `wifiap-binding` = la carte **émet** un WiFi (hostapd AP + dnsmasq DHCP).
- Se connecter à un WiFi **existant** = `wpa_supplicant` + `systemd-networkd`
  (voir `docs/wifi-rpi3b-brcmfmac.md`).

## Références

- docs.redpesk.bzh → redpesk-core : services-list, afb-librust, canbus,
  canopen, modbus, gps, secure-storage, platform-info, spawn, secure-gate,
  redpak-binding, wifiap-binding
- Dépôts : github.com/redpesk-common, redpesk-industrial, redpesk-addons,
  redpesk-labs, redpesk-samples