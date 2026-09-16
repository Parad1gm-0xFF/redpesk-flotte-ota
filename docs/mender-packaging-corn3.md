# Mender sur redpesk corn 3.x : activation et état (OTA).

Constat et procédure, 16/09/2026. RPi3B+ sous redpesk corn 3.0.

## Cause initiale : repo third-party non activé (RÉSOLU)

L'erreur `dnf install mender-redpesk` →
`nothing provides mender-client >= 5.0.0` venait simplement du fait que le
**repo `redpesk-third-party` n'était pas activé**.

Activation (doc redpesk, os-tips/thirdparty) :

```
echo 1 > /etc/dnf/vars/redpesk_third_party
dnf install -y mender-redpesk mender-connect
```

Ce repo fournit (aarch64, corn 3.0 et 3.1) :
- `mender-client 5.0.3`
- `mender-connect 2.3.1`
- `mender-redpesk 2.0.0` (identité + inventaire + `mender-init.sh`)

> Correction d'une conclusion antérieure : `mender-client` n'est PAS absent de
> l'écosystème redpesk, il est dans **third-party**, désactivé par défaut.

## Résultat obtenu

- Binaires : `mender-auth`, `mender-update`, `mender-connect`, `mender-init.sh`
- Services actifs : `mender-authd`, `mender-updated`, `mender-connect`
- Identité : `mender-init.sh --force -d rpi3b-flotte -k "<clé>"` →
  `/var/lib/mender/mender-agent.pem`
- Le client **atteint le serveur** `https://community-mender.redpesk.bzh`
  (config préexistante dans `/etc/mender/mender.conf`)

## Point en cours : « dev auth: unauthorized »

Malgré une board **préautorisée** côté factory (`rp-cli boards add rpi3b-01
--board-model rpi3b-flotte --mac-address <mac> --pre-authorize`), le device
reçoit :

```
Unauthorized error: Failed to authorize with the server.
({"error":"dev auth: unauthorized", "request_id": ...})
```

Pistes de mismatch d'identité Mender (à confirmer) :
- **Attribut MAC** : le script d'identité redpesk envoie `mac_addr=<mac>`
  (et `device_type=<type>`). La préautorisation factory (`--mac-address`) cible
  peut-être un autre nom d'attribut (`mac`).
- **device_type** : le modèle s'affiche `rpi3b-flotte_91c8e506` (name_id) alors
  que le device envoie `rpi3b-flotte`. La chaîne attendue est à confirmer.
- **MAC utilisée** : le script prend l'interface de plus bas ifindex (ici
  `wlan0` : `b8:27:eb:dd:8a:3c`) ; l'Ethernet est `b8:27:eb:88:df:69`.
- **Acceptation explicite** : `rp-cli boards update <id> --accept [--auth-ID]`
  pourrait être nécessaire selon la config serveur.

## Note opérationnelle : horloge

L'image minimale n'a **ni RTC ni NTP**. L'horloge est fausse au boot, ce qui
casse la validation TLS vers le serveur Mender. Contournement de test :
`date -s "<heure>"`. Correctif durable : installer `chrony` (ou activer un
service de temps) et un RTC.

## Références

- docs.redpesk.bzh → os-tips/thirdparty (repo third-party), additionnal_repos
  (EPEL/Rocky), os-ota/1-mender-redpesk, redpesk-factory/models-boards-management
- Repo redpesk-third-party : `download.redpesk.bzh/redpesk-lts/corn-3.0-update/packages/third-party/<arch>/os/`