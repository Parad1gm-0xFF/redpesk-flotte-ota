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

## Déploiement factory : RÉSOLU (erreur d'usage, pas un bug)

> Correction d'une conclusion antérieure erronée. Un premier essai de
> déploiement avait produit une erreur serveur que j'avais qualifiée de « bug
> plateforme ». En relisant la procédure, la cause était une **option
> manquante** de ma part.

`rp-cli project-releases deploy` **requiert de préciser les RPMs** via `--rpms`
(sinon la création d'artefact échoue côté factory). Commande correcte :

```
rp-cli project-releases deploy <release-id> --boards <board-id> -a aarch64 \
    --rpms <package-name>
```

Résultat observé (aucune erreur) :

```
-- Released project deployment requested by user --
Requesting the factory to deploy the project "secure-telemetry-node-1-1.0.0"...	[OK]
```

Le déploiement est accepté par la factory. Le device (authentifié) récupérera
l'artefact à son prochain cycle de poll.

Notes :
- La doc OTA (`models-boards-management`) ne documente pas la commande de
  déploiement CLI ; `--rpms` vient de l'arbre des commandes
  (`rp-cli project-releases deploy --help`).
- `rp-cli deployments list` peut renvoyer « invalid endpoint or API call »
  (endpoint de listing indisponible sur le Community) ; cela n'empêche pas le
  déploiement.
- La doc « Project releasing » rappelle que les paquets d'un projet releasé
  sont **signés par la factory**, et qu'il faut activer `gpgcheck` sur la
  board (`dnf config-manager --setopt=<repoid>.gpgcheck=1 --save`) pour que
  dnf vérifie ces signatures.

### La carte récupère le déploiement (vérifié)

Après acceptation, le device **télécharge et traite** l'artefact (extrait du
journal `mender-updated`) :

```
Deployment with ID a7a13120-... started.
Parse error: Failed to parse the manifest: ... filename
  (secure-telemetry-node-0.0.0202609071326270g348adf9-11.secure.telemetry.node.1_fb68c347.rpcorn.aarch64.rpm)
  is too long, maximum allowed filename length is 100
Deployment ... finished with status: Failure
```

Donc la chaîne factory -> device **fonctionne** (l'artefact descend). L'échec
vient d'une **limite Mender** : le nom du RPM dans le manifeste dépasse
**100 caractères** (ici 105), à cause de la **version auto-générée très longue**
par la factory (`setverrel`).

Pistes de correction (côté projet/version, pas la plateforme) :
- activer le **« short release naming »** du projet (champ vu dans
  `rp-cli projects get -v` ; non exposé dans `projects update` — à faire via
  la WebUI) ;
- ou désactiver la génération auto de version/release (`setverrel`) et fixer
  un `Version`/`Release` courts dans le specfile ;
- ou viser un paquet dont le nom d'archive reste court.

## Reste à faire pour un déploiement complet

1. `jq` manquant sur l'image (l'inventaire `repos-info` échoue, non bloquant) :
   `dnf install jq` (a échoué en GPG check un jour donné, à revoir).
2. Attendre le poll du device (30 min) ou le forcer, puis vérifier l'update.
3. Activer `gpgcheck` sur la board pour vérifier les signatures factory.

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
- L'OTA est pilotée par la factory (SaaS), indépendamment de l'OS du device.
  Les releases OS (Arz/Batz/Corn) n'entrent pas en jeu pour le déploiement.
- Le **GPG check activé par défaut** (1.10.0) explique l'échec `dnf install jq`
  (paquets third-party non signés par la clé attendue).
- ROADMAP OS : Arz (RHEL8) → Batz (RHEL9, supporté jusqu'en 2029) → Corn (RHEL10).

## Voie alternative : artefact local (mender-artifact)

Deux approches complémentaires :

1. **Local builder redpesk** (doc `redpesk-factory/2_mender.html`) :
   `make-mender-artifact` / `upload-mender-artifact`, autour de **Hosted Mender**
   (`eu.hosted.mender.io`).
2. **Outil officiel `mender-artifact`** (image Docker `mender-ci-tools`) : créer
   un artefact localement et le déployer en standalone (validé, voir
   `docs/artefact-local.md`).

## Note opérationnelle : horloge

L'image minimale n'a **ni RTC ni NTP**. L'horloge est fausse au boot, ce qui
casse la validation TLS vers le serveur Mender. Contournement de test :
`date -s "<heure>"`. Correctif durable : installer `chrony` (ou activer un
service de temps) et un RTC.

## Références

- docs.redpesk.bzh → os-tips/thirdparty (repo third-party), additionnal_repos
  (EPEL/Rocky), os-ota/1-mender-redpesk, redpesk-factory/models-boards-management
- Repo redpesk-third-party : `download.redpesk.bzh/redpesk-lts/corn-3.0-update/packages/third-party/<arch>/os/`