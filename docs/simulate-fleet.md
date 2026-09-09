# Simuler une flotte avec un seul RPi 3B+.

Objectif : valider le workflow OTA (provisionnement, enregistrement Mender,
déploiement, rollback) sans multiplier les cartes physiques.

## Principe

La flotte simulée est composée de :
- **1 board réelle** : le RPi3B+ (redpesk OS, Ethernet)
- **N boards virtuelles** : VMs QEMU x86_64 exécutant des images redpesk OS
  sur le poste de dev

Chaque membre (réel ou virtuel) s'identifie côté factory Mender par
**MAC + device type + clé privée**, exactement comme une board physique.

## 1. Télécharger l'image QEMU (x86_64)

Source officielle : `https://download.redpesk.bzh` (chemin documenté dans
docs.redpesk.bzh, section "Booting a redpesk image with QEMU").

Répertoire : `redpesk-lts/corn-3.0-update/images/smack/minimal/x86_64/generic/`

```
mkdir -p ~/vm-images && cd ~/vm-images
# Télécharger image.raw.tar.xz + son sha256 (vérifier le hash !)
# Extraire : Redpesk-OS.img
```

> **Emplacement de l'image** : `~/vm-images/Redpesk-OS.img`
> (HORS du workspace Nextcloud : l'image fait ~5 Go et saturerait la
> synchro. `launch-vm.sh` la cherche automatiquement dans `~/vm-images/`
> puis dans `vm-fleet/` en fallback. Elle n'est jamais commitée ni poussée.)

Vérifier l'intégrité avec le `.sha256` fourni AVANT tout usage.

## 2. Dépendances hôte

- QEMU (x86_64 + KVM)
- OVMF (firmware UEFI) : paquet `edk2-ovmf` sur Fedora, `ovmf` sur Debian/Ubuntu

## 3. Démarrer une board virtuelle

```
./scripts/vm-fleet/launch-vm.sh 1   # SSH sur port 3301, MAC b8:27:eb:00:00:01
./scripts/vm-fleet/launch-vm.sh 2   # SSH sur port 3302
```

Connexion par mot de passe : `ssh -p 3301 root@localhost` (mot de passe `root` par défaut).

### Accès SSH par clé (recommandé)

Pour se connecter sans mot de passe (et permettre au script `provision-vm.sh`
de tourner en non-interactif), injecter une clé publique dans l'image AVANT le
premier boot, ou depuis la console série quand la VM tourne.

**Depuis la console série** (VM déjà démarrée, socket `/tmp/vmN.sock`) :

```
# depuis l'hôte, servir la clé : (cd /tmp/opencode/serve && python3 -m http.server 8899)
# puis dans la console root de la VM :
rm -rf /root/.ssh/authorized_keys
curl -s http://10.0.2.2:8899/authorized_keys > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
```

**Méthode image (offline)** avec `sudo` :

```
# Partition ROOT de Redpesk-OS.img = offset 1651507200 (parted -s ... unit B print)
sudo mount -o loop,offset=1651507200 ~/vm-images/Redpesk-OS.img /mnt/vmrootfs
sudo mkdir -p /mnt/vmrootfs/root/.ssh
cat <clé>.pub | sudo tee /mnt/vmrootfs/root/.ssh/authorized_keys
sudo umount /mnt/vmrootfs
```

> **Piège connu** : sur l'image redpesk QEMU, `/root/.ssh/authorized_keys` peut
> se retrouver sous forme de RÉPERTOIRE (mode `01777`), ce qui fait échouer
> SSH (« Permission denied » malgré la bonne clé). Diagnostic :
> `debugfs -R "stat /root/.ssh/authorized_keys" rootfs.img` → « Type: directory ».
> Correction : `rm -rf /root/.ssh/authorized_keys` puis recréer le fichier.
> Ce bug se réapplique si l'image est régénérée depuis le tarball.

## 4. Enregistrer la board virtuelle dans la flotte

Identique à une board physique (script concerné côté cible) :

```
# depuis la VM (ou via ssh -p 330X root@localhost)
./scripts/target/provision.sh rpi3b-flotte <clé_privée.pem>
```

Puis côté factory :
```
./scripts/factory/status.sh   # la VM doit apparaître / accepter la clé
```

## 5. Déployer (OTA)

```
./scripts/factory/deploy.sh "test flotte VM 1"
```

La VM reçoit la mise à jour Mender comme une board réelle, avec rollback A/B
si l'image est buildée avec Mender (contrainte documentée dans le README).

## Limites

- L'image `Redpesk-OS.img` pré-construite ne fait pas l'OTA A/B d'origine : le
  vrai bout-en-bout Mender exige une image custom buildée avec Mender activé
  (phase suivante).
- Une VM QEMU exige `-enable-kvm` : sans KVM (VM dans VM), passer en TCG
  (`-machine accel=tcg`), plus lent.
- Le réseau `user` QEMU ne permet pas à la VM de recevoir des connexions
  entrantes Mender : le forwarding `hostfwd` suffit pour SSH, mais le
  *polling* Mender client -> serveur fonctionne (sortie entrante autorisée).
- La VM joint l'hôte via `10.0.2.2` (passerelle du réseau user-mode) : utile
  pour servir un fichier local (ex. `python3 -m http.server`) et le
  télécharger dans la VM avec `curl http://10.0.2.2:<port>/<fichier>`.