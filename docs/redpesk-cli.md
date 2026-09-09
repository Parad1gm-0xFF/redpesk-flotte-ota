# redpesk-cli : commandes utiles pour la flotte.

Sources : docs.redpesk.bzh (`redpesk-factory/rp_cli/*`) et `rp-cli <cmd> --help`.

## Configuration initiale

```bash
rp-cli onboard                        # interactive : URL factory, token, projet
rp-cli connections list               # vérifier la connexion courante
rp-cli misc status                    # état de l'infrastructure
```

## Projets

```bash
rp-cli projects add <project>         # créer un projet
rp-cli projects get <project>
rp-cli projects list
```

## Model board / boards (OTA)

```bash
# Un model board == un device type Mender.
rp-cli board-models add               # options: --name, --configuration (fichier yml)
rp-cli board-models list
rp-cli boards add --name <n> --mac <mac> --model-board <mb>
rp-cli boards list
rp-cli boards update <id>             # accepter/rejeter une board (auth Mender)
```

## Déploiement (release + OTA)

```bash
rp-cli projects release <project> --message "vX.Y.Z"
rp-cli project-releases list
rp-cli project-releases deploy <release-id> --model-board <mb>
rp-cli deployments list               # suivi des déploiements
rp-cli deployments get <id>
```

## Divers

```bash
rp-cli images list                    # images OS disponibles
rp-cli applications build <app>       # build d'une app RPM
rp-cli applications test <id>         # test embarqué sur VM/QEMU
```

## Notes

- Les commandes OTA (`board-models`, `boards`, `deployments`) sont de la
  catégorie « uniquement OTA » : elles concernent Mender, côté factory.
- La board apparaît « pré-autorisée » dès sa création ; elle passe en
  « acceptée » à la première authentification Mender de la carte (clé privée
  côté cible, clé publique hashée côté factory).
- `rp-cli` étant très verbeux, chaque script l'appelle avec des arguments fixes
  et documentés ; adapter les options selon la version de la factory
  (`rp-cli --help` reste la référence vivante).