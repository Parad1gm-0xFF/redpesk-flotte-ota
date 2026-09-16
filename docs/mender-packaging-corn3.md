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

### OTA factory bout-en-bout : RÉUSSIE (vérifié)

Après deux ajustements, le déploiement s'installe complètement (journal du
device) :

```
Deployment ... started.
Installing artifact...
Payload is of RPM type
Verifying packages...
Preparing packages...
secure-telemetry-node-0.1.0-1.secure.telemetry.node.1_fb68c347.rpcorn.aarch64
RPM successfully installed!
Deployment ... finished with status: Success
$ rpm -q secure-telemetry-node
secure-telemetry-node-0.1.0-1.secure.telemetry.node.1_fb68c347.rpcorn.aarch64
$ mender-update show-artifact
secure-telemetry-node-1-1.1_21aed459-...
```

Deux ajustements nécessaires :

1. **Nom de fichier < 100 caractères (limite Mender)**. La version
   auto-générée par la factory (`setverrel`) produisait un nom de RPM de 105
   caractères, rejeté au parsing du manifeste
   (`maximum allowed filename length is 100`). Solution : **désactiver le
   service `setverrel`** sur l'application, pour utiliser le `Version`/`Release`
   courts du specfile (`0.1.0-1`) :
   ```
   rp-cli applications update secure-telemetry-node -p secure-telemetry-node-1 \
       --disable-services setverrel
   ```
   puis rebuild + re-release. Nom obtenu : 81 caractères.
   (Alternative côté projet : « short release naming » — champ visible dans
   `rp-cli projects get -v` mais non exposé par `projects update` ; à faire via
   la WebUI.)

2. **Clé GPG de la factory importée sur la cible** (le module exige des RPM
   signés) :
   ```
   rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-community
   ```
   Sans elle : `Header V4 RSA/SHA256 Signature, key ID f7ea2b49: NOKEY`.
   Cohérent avec la doc « Project releasing » (les paquets d'un projet releasé
   sont signés par la factory).

3. **Délai de propagation de la release** : déployer juste après un
   `projects release` peut échouer (`NameError: name 'urls' is not defined`
   dans `download_packages`) ; réessayer ~1 à 2 min plus tard suffit.

## Points restants (non bloquants)

1. `jq` manquant sur l'image (l'inventaire `installed-packages`/`repos-info`
   échoue, non bloquant). `dnf install jq` a échoué en GPG check une fois.
2. Poll device : 30 min par défaut ; réduire `UpdatePollIntervalSeconds` ou
   redémarrer `mender-updated` pour accélérer un test.
3. A/B (mise à jour d'OS) : nécessite une image Mender (partitionnement A/B) ;
   l'OTA démontrée ici est une **mise à jour d'application** (RPM).

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