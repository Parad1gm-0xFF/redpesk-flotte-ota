# P5 : Zephyr dans la factory redpesk (preuve sans matériel).

Objectif : construire et valider une application Zephyr dans la **redpesk
factory**, cible `qemu_x86_64`, sans aucun matériel embarqué supplémentaire.

Résultat (13/09/2026) : **preuve complète**.
L'app `zephyr-hello-world` (sample Zephyr in-tree) est buildée dans la
factory Community (build 55090) et affiche sous QEMU :

```
*** Booting Zephyr OS build 4.2.1 ***
Hello World! qemu_x86_64/atom
```

## Pourquoi

- Démontre l'**intégration native Zephyr dans redpesk** (build, packaging RPM,
  firmware dans `/lib/firmware`), un des points forts de l'écosystème IoT.bzh.
- Cible `qemu_x86_64` : aucune carte à acheter, preuve rejouable.

## Étapes (refaites le 13/09/2026)

### 1. Projet (factory)

```
rp-cli projects add -n zephyr-qemu-demo --applications \
  --mandatory-arch x86_64 \
  --mandatory-distro redpesk-zephyr-latest \
  --description "Preuve Zephyr hello-world qemu_x86_64"
```

- Distribution utilisée : `redpesk-zephyr-latest` (Zephyr 4.2.0 en 4.2.1 au build).

### 2. Application

```
rp-cli applications add -n zephyr-hello-world --pkg-name zephyr-hello-world \
  -p zephyr-qemu-demo --mandatory-distro redpesk-zephyr-latest
```

- Specfile interne remplacé par le **template officiel redpesk-samples** :
  `redpesk-samples/specfile-samples/master/zephyr/zephyr-hello-world.spec`
  (définit `qemu_x86_64` + toolchain x86_64).
- Le specfile est téléchargé localement puis uploadé :
  `rp-cli applications files upload <app-slug> -p zephyr-qemu-demo zephyr-hello-world.spec`

### 3. Build (long)

```
rp-cli applications build <app-slug> -p zephyr-qemu-demo --nonblocking
# suivi : rp-cli applications builds list <slug> -p zephyr-qemu-demo
```

- Résultat : build **55090** `done`.
- Artefact : `zephyr-hello-world-0.0.0-0...rpcorn.x86_64.rpm`
  (`rp-cli applications builds download <id> -p zephyr-qemu-demo`)

### 4. Preuve locale QEMU

Le RPM contient les firmwares Zephyr installés dans `/lib/firmware` :

```
./lib/firmware/zephyr-qemu-locore.elf
./lib/firmware/zephyr-qemu-main.elf
./lib/firmware/zephyr-hello-world.elf
./lib/firmware/zephyr-qemu.elf
```

Extraction (poste dev, sans root) :

```
mkdir -p fw && cd fw
7z x <rpm> -oext   # extrait le cpio
cd ext && cpio -idm < *.cpio   # extrait lib/firmware/
```

Lancement (script du repo, syntaxe QEMU corrigée par rapport à la doc
redpesk) :

```
./scripts/zephyr/test-local.sh fw/lib/firmware
```

Sortie attendue :

```
SeaBIOS (version 1.17.0-debian...)
Booting from ROM..
*** Booting Zephyr OS build 4.2.1 ***
Hello World! qemu_x86_64/atom
```

## Correction de la doc redpesk (commande QEMU)

La commande de la doc `zephyr-user-workflow.html` contient deux erreurs de
syntaxe QEMU :

| Doc | Correction |
|---|---|
| `-serial chardev:con` | ok |
| `-mon chardev:con,mode=readline` | `-mon chardev=con,mode=readline` |

(La doc écrit `-mon chardev:con` : invalide. La série `-serial chardev:con` est
valide, c'est le `-mon` qui doit utiliser le séparateur `=`.)

## Note d'environnement

- Compte redpesk **Community** : l'infra a parfois des erreurs de lecture
  (`read on closed response body`) sur logs/téléchargement ; les artefacts
  finissent par être récupérables ; le build, lui, passe.
- Le build Zephyr est long (DL toolchain + compilation) : prévoir `--nonblocking`.