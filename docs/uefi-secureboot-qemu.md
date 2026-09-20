# UEFI Secure Boot en QEMU (démonstration).

Objectif : démontrer **UEFI Secure Boot** sans matériel, en QEMU + OVMF.
**Statut : validé (20/09/2026).**

## Principe

- OVMF (firmware UEFI) en mode **secure boot** (`OVMF_CODE_4M.secboot.fd`).
- Une base de variables OVMF où l'on **enrôle nos propres clés** (PK, KEK, db).
- Un chargeur EFI **signé** avec la clé `db` → accepté ; le **même non signé** →
  rejeté par le firmware.

## Outils

- `qemu-system-x86_64`, OVMF (`/usr/share/OVMF/` : `OVMF_CODE_4M.secboot.fd`,
  `OVMF_VARS_4M.fd`).
- `sbsign` / `sbverify` (paquet `sbsigntool`).
- `virt-fw-vars` (`pip install --user virt-firmware`) pour enrôler les clés.
- Un binaire EFI lisible : `/usr/lib/grub/x86_64-efi/monolithic/grubx64.efi`.

## Procédure

```
cd /tmp/opencode/secureboot

# 1. Clés PK / KEK / db
for n in "PK:Platform Key" "KEK:Key Exchange Key" "db:Signature Database"; do
  k=${n%%:*}; c=${n##*:}
  openssl req -new -x509 -newkey rsa:2048 -keyout $k.key -out $k.crt \
      -days 3650 -nodes -subj "/CN=$c/"
  openssl x509 -in $k.crt -outform DER -out $k.der
done

# 2. Enrôlement dans une copie des VARS OVMF
G=77fa9abd-0359-4d32-bd60-28f4e78f784b
virt-fw-vars --input /usr/share/OVMF/OVMF_VARS_4M.fd --output my_vars.fd \
  --set-pk $G PK.der --add-kek $G KEK.der --add-db $G db.der

# 3. ESP signé + variante non signée
GRUB=/usr/lib/grub/x86_64-efi/monolithic/grubx64.efi
mkdir -p esp/EFI/BOOT esp-unsigned/EFI/BOOT
sbsign --key db.key --cert db.crt --output esp/EFI/BOOT/BOOTX64.EFI "$GRUB"
cp "$GRUB" esp-unsigned/EFI/BOOT/BOOTX64.EFI
sbverify --cert db.crt esp/EFI/BOOT/BOOTX64.EFI          # -> OK
sbverify --cert db.crt esp-unsigned/EFI/BOOT/BOOTX64.EFI # -> failed

# 4. Boot (remplacer esp par esp-unsigned pour le cas négatif)
qemu-system-x86_64 -machine q35,smm=on -m 2048 \
  -global driver=cfi.pflash01,property=secure,value=on \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd \
  -drive if=pflash,format=raw,file=my_vars.fd \
  -drive file=fat:rw:esp,format=raw \
  -vga std -display none
```

## Résultats

- **Signé** : `GNU GRUB version 2.14` s'affiche → le firmware a **vérifié** la
  signature et lancé le chargeur.
- **Non signé** :
  ```
  BdsDxe: failed to load Boot0001 ... : Access Denied -- rejected probably by Secure Boot
  BdsDxe: No bootable option or device was found.
  ```

## Pièges / notes

- OVMF (x86) affiche sur **VGA**, pas sur le série : capturer via le moniteur
  QEMU (`screendump`) plutôt que `-nographic`.
- Disque ESP virtuel : utiliser `-drive file=fat:rw:<dir>,format=raw`
  (`fat:ro:` provoque « Block node is read-only »).
- Secure boot OVMF exige `-machine q35,smm=on` + `-global
  driver=cfi.pflash01,property=secure,value=on`.
- C'est un secure boot **émulé** (clés logicielles). La racine de confiance
  matérielle (eFuses/SRK, HAB) n'est pas émulable → vraie carte NXP requise.

## Lien avec redpesk

La doc redpesk confirme qu'en **x86_64** le Secure Boot repose sur **UEFI**
(c'est ce qui est démontré ici). Pour un OTA redpesk x86_64, il faudrait que le
chargeur/noyau de l'image soient signés par une clé enrôlée.