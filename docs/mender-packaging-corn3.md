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
2. **BUG PLATEFORME (bloquant)** : le déploiement échoue côté serveur factory.

### Bug redpesk : POST /deployments (create_artifact)

Reproductible via `rp-cli project-releases deploy <release> --boards <board> -a aarch64` :

```
Error: oops, something went wrong - {"errors":
 "type object 'datetime.time' has no attribute 'sleep'",
 "traceback": [ ... redpesk_service_ota/mender/artifact.py", line 252,
                in create_artifact:  time.sleep(0.5) ]}
```

Cause : dans `redpesk_service_ota/mender/artifact.py`, `time` a été importé
comme `datetime.time` (classe) au lieu du module `time`, donc `time.sleep()`
n'existe pas. Bug **serveur** (factory), indépendant du device.

Conséquence : l'artefact OTA ne peut pas être créé/déployé par la factory tant
que ce point n'est pas corrigé côté redpesk. Le device, lui, est authentifié et
prêt (il poll, prêt à installer un artefact).

## Analyse : changer de release OS ne débloque pas l'OTA

L'OTA est une **fonctionnalité de la factory**, pas de l'OS. Notes de release
factory (`redpesk-factory/factory-releases`) :

- **Armel 1.8.0 (fév. 2025)** : « OTA (Over The Air) support for deployments on
  boards » (introduction de l'OTA).
- **Armel 1.10.0 (nov. 2025)** : « Deployment: add possibility to deploy uniquely
  few rpms » ; « **Enable GPG check by default in redpesk images** ».
- **Armel 1.11.1 (juil. 2026)** : « Fix several bugs around OTA feature »
  (version actuelle de la factory Community, cf. `rp-cli misc version` = 1.11.1).
- **Armel 1.0.1 (août 2022)** : premières briques « mender/OTA tools and scripts »
  (local builder).

Conséquences :
- Le bug `create_artifact` que nous rencontrons est **côté service factory**
  (SaaS 1.11.1), donc **indépendant de l'OS du device**. Revenir à Batz 2.x ou
  Arz n'aurait aucun effet sur ce bug.
- Le **GPG check activé par défaut** (1.10.0) explique l'échec `dnf install jq`
  (paquets third-party non signés par la clé attendue).
- ROADMAP OS : Arz (RHEL8) → Batz (RHEL9, supporté jusqu'en 2029) → Corn (RHEL10).

## Voie alternative : artefact local (make-mender-artifact)

La doc `redpesk-factory/2_mender.html` décrit un chemin **sans l'endpoint cassé** :
le **local builder** fournit `make-mender-artifact` et `upload-mender-artifact`
pour créer/pousser un artefact directement. Réserve : ce flux est documenté
autour de **Hosted Mender** (`eu.hosted.mender.io`), alors que notre device est
inscrit sur `community-mender.redpesk.bzh`.

Piste : utiliser l'outil **officiel Mender** `mender-artifact` (binaire Go) pour
créer un artefact depuis nos RPM, puis le déployer via l'UI/API du serveur
Mender de la factory. Voir `docs/artefact-local.md` (exploration).

## Note opérationnelle : horloge

L'image minimale n'a **ni RTC ni NTP**. L'horloge est fausse au boot, ce qui
casse la validation TLS vers le serveur Mender. Contournement de test :
`date -s "<heure>"`. Correctif durable : installer `chrony` (ou activer un
service de temps) et un RTC.

## Références

- docs.redpesk.bzh → os-tips/thirdparty (repo third-party), additionnal_repos
  (EPEL/Rocky), os-ota/1-mender-redpesk, redpesk-factory/models-boards-management
- Repo redpesk-third-party : `download.redpesk.bzh/redpesk-lts/corn-3.0-update/packages/third-party/<arch>/os/`