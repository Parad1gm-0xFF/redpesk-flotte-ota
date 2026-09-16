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

## Point RÉSOLU : « dev auth: unauthorized » = device_type

Le mismatch venait du **`device_type`**. La factory attend la chaîne
`<model_name>_<model_id>` et non le seul nom du modèle.

Détail brut factory (`rp-cli boards get <id> --rawoutput`) :

```json
"model_name":  "rpi3b-flotte",
"device_type": "rpi3b-flotte_91c8e506",   // <- la valeur attendue
"mac_address": "b8:27:eb:dd:8a:3c",
"server_status": "preauthorized"
```

Correction appliquée sur le device :

```
echo 'device_type=rpi3b-flotte_91c8e506' > /var/lib/mender/device_type
echo 'device_type=rpi3b-flotte_91c8e506' > /etc/mender/device_type
systemctl restart mender-authd mender-updated
```

Résultat :

```
mender-authd: Successfully received new authorization data
mender-updated: Inventory data submitted successfully
mender-updated: No update available
```

→ **Le RPi3B+ est authentifié auprès du serveur Mender de la factory** et
soumet son inventaire. La chaîne OTA est opérationnelle côté client.

## Reste à faire pour un déploiement complet

1. `jq` manquant sur l'image (l'inventaire `repos-info` échoue, non bloquant) :
   `dnf install jq` (a échoué en GPG check un jour donné, à revoir).
2. Créer un artefact/release dans la factory et le déployer sur la board
   (`rp-cli project-releases` / `make-mender-artifact`), puis observer l'update.

## Note opérationnelle : horloge

L'image minimale n'a **ni RTC ni NTP**. L'horloge est fausse au boot, ce qui
casse la validation TLS vers le serveur Mender. Contournement de test :
`date -s "<heure>"`. Correctif durable : installer `chrony` (ou activer un
service de temps) et un RTC.

## Références

- docs.redpesk.bzh → os-tips/thirdparty (repo third-party), additionnal_repos
  (EPEL/Rocky), os-ota/1-mender-redpesk, redpesk-factory/models-boards-management
- Repo redpesk-third-party : `download.redpesk.bzh/redpesk-lts/corn-3.0-update/packages/third-party/<arch>/os/`