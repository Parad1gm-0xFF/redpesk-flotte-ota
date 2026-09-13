# Mender / OTA : blocage de packaging sur redpesk corn 3.0.

Constat fait le 09/09/2026, en préparant le provisionnement OTA d'un RPi3B+
(et d'une VM x86_64). Objectif : documenter précisément le blocage, pour ne
pas le perdre et pour remonter proprement le cas à IoT.bzh.

## Symptôme

L'installation du client Mender via les dépôts redpesk échoue :

```
# sur le RPi (aarch64) et sur la VM (x86_64) — même échec
$ dnf install mender-redpesk
Error:
 Problem: conflicting requests
  - nothing provides mender-client >= 5.0.0 needed by mender-redpesk-2.0.0-4.redpesk.common.rpcorn.noarch from redpesk-middleware-update
```

`mender-redpesk` 2.0.0 est présent dans `redpesk-middleware-update`, mais sa
dépendance `mender-client >= 5.0.0` n'est fournie par **aucun** des dépôts
configurés sur l'image corn 3.0 :

```
available/repoquery, tous repos activés (=y compris désactivés hors debug/source) :
  mender-redpesk-0:2.0.0-4.redpesk.common.rpcorn.noarch   (seul paquet mender* trouvé)
```

## Ce qui a été vérifié

- **Toutes architectures** : le paquet manquant est absent aussi bien en
  `aarch64` (RPi3B+) qu'en `x86_64` (VM QEMU). Ce n'est pas lié à l'arch.
- **Tous les dépôts redpesk** : `redpesk-baseos`, `redpesk-baseos-update`,
  `redpesk-middleware`, `redpesk-middleware-update`, énérables et désactivés
  (`--enablerepo='*'`), ne contiennent pas `mender-client`.
- **Après swap de `redpesk-config` vers la factory Community** (1.5.1-5.community) :
  toujours pas de `mender-client`.
- **Source Mender officielle** : le client `mender-client` RPM n'est pas
  publié dans un repo dnf public simple (Mender fournit des paquets Debian et
  l'intégration Yocto ; pas de repo RPM CentOS/Rocky prêt à l'emploi).

## Conséquence pour ce projet

- La démo OTA Mender **bout-en-bout ne peut pas être menée telle quelle** sur
  l'image redpesk corn 3.0 standard :
  - sur le RPi réel (aarch64) : `mender-client` absent des dépôts
  - sur les VMs (x86_64) : idem
- Ce que l'on peut faire en attendant :
  - valider le **provisionnement cible** (Mender identity, config factory,
    scripts `redpesk-flotte-ota`) qui ne dépend pas de `mender-client` ;
  - tester l'OTA en local avec **Mender auto-test / simulateur** ou une image
    Mender-convert (hors redpesk) si besoin de démonstration.

## Pistes de résolution à remonter à IoT.bzh

1. **Dépendance `mender-client >= 5.0.0` non référencée** dans les dépôts de
   la release `corn-3.0-update` : paquet à publier (ou dependency à assouplir
   si le `mender-redpesk` embarquait le client).
2. **mender-connect** absent aussi des dépôts x86_64 (optionnel, mais
   mentionné dans la doc d'installation RPi).
3. Question ouverte : sur quelles images redpesk le RPi3B+ OTA a-t-il été
   validé ? Quelle version du client Mender ? Peut-être une version d'OS
   antérieure (arz 1.x) contient-elle `mender-client` ?

## Références

- docs.redpesk.bzh : `redpesk-os/os-ota/1-mender-redpesk.html` (doc install :
  `dnf install mender-redpesk mender-connect`)
- docs.redpesk.bzh : `redpesk-factory/models-boards-management/` (OTA côté factory)
- bugzilla.redhat.com : pattern similaire (dépendance manquante binaire)
- docs.mender.io : client RPM non publié dans un repo dnf public (Debian+Yocto only)