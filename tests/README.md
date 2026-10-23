# Scénarios de validation (V1 à V6)

Responsable : **THIOMBIANO Yempabou Romaric Johan** (ingénieur essais et observabilité)

Tous les scripts se lancent **depuis l'hôte** (Git Bash sous Windows), à la racine du dépôt.
Chaque script enregistre son **résultat brut** dans `tests/resultats/` : ces fichiers sont versionnés,
car ce sont les preuves des chiffres du dossier. Une mesure qui ne figure pas ici n'existe pas.

| Script | Scénario | Responsable | État |
|---|---|---|---|
| `v1_repartition.sh` | 20 appels à `/info`, écart entre serveurs < 20 % | THIOMBIANO | à écrire |
| `v2_panne_app.sh` | `vagrant halt app1` pendant une charge | KOBENDE (rotation) | à écrire |
| `v3_montee_charge.sh` | `ab -n 2000 -c 50` avec N=2 puis N=4 | THIOMBIANO | à écrire |
| `v4_panne_bdd.sh` | `vagrant halt bdd1`, `/sante` → 503, bascule chronométrée | OUEDRAOGO / THIOMBIANO | à écrire |
| `v5_reconstruction.sh` | `vagrant destroy -f` puis `vagrant up`, durée totale | THIOMBIANO | à écrire |
| `v6_panne_lb.sh` | `vagrant halt lb1`, service joignable sur l'IP virtuelle | PORGO (rotation) | **mesuré** : 1/122 perdue, 1,73 s |
| `verifier_repartition.sh` | R2 (idempotence), R3 (NB_APP), R4 (éviction < 5 s), R8 (ports) | PORGO | **mesuré** |

## Adresse à interroger

- Avec l'extension E1 : l'**IP virtuelle** `http://192.168.(55+G).5/` (elle survit à la perte de lb1).
- Sans E1 : `http://localhost:8080/`.

Le script peut la lire dans la source de vérité :

```bash
VIP=$(sed -n 's/.*"vip": *"\([^"]*\)".*/\1/p' config/plateforme.json)
```

## Outils sur l'hôte

- `curl` : fourni avec Git Bash.
- `ab` (Apache Bench) : sous Windows, récupérer `ab.exe` dans l'archive Apache httpd
  d'Apache Lounge (dossier `bin/`) et le placer dans le `PATH`. Toujours noter la commande exacte.
- Le serveur qui a répondu est indiqué par l'en-tête `X-Serveur` posé par HAProxy :
  `curl -sI http://$VIP/info | grep -i x-serveur`.

## Honnêteté des mesures

Toutes les machines virtuelles partagent le processeur d'un seul ordinateur : doubler N ne double pas
le débit. Relever la configuration du poste (CPU, RAM) avec chaque mesure, et commenter ce qui est observé.
