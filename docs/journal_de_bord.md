# Journal de bord : RÉSULTATS-BF

> Livrable L3, 1 à 2 pages. **Chacun ajoute ses entrées au fil de l'eau** (date, auteur, décision ou difficulté).

## Répartition des rôles

| Membre | Rôle |
|---|---|
| PORGO Abdoul Nassirou | Architecte réseau et répartition (E1) |
| KOBENDE Pêgdwendé Evrard | Ingénieur applicatif |
| OUEDRAOGO Armand Hendrix | Ingénieur données |
| THIOMBIANO Yempabou Romaric Johan | Ingénieur essais et observabilité (E2) |

## Décisions prises et pourquoi

| Date | Auteur | Décision | Raison |
|---|---|---|---|
| 23/10 | PORGO | HAProxy plutôt que Nginx comme répartiteur | Sonde HTTP active sur `/sante` (Nginx libre ne fait que des contrôles passifs), rejeu `retry-on`, page de stats et métriques Prometheus intégrées |
| 23/10 | PORGO | Configuration HAProxy/keepalived engendrée par un script Python depuis `plateforme.json` | R3 : aucune adresse en dur, même source que le Vagrantfile |
| 23/10 | PORGO | `.env` créé automatiquement au premier `vagrant up` | Concilier R1 (aucun geste manuel) et R7 (aucun secret versionné) |
| 23/10 | PORGO | VRRP en unicast, les deux LB en BACKUP avec priorités 150/100 | Ne pas dépendre du multicast du réseau hôte-seul ; éviter un double maître au démarrage |
| 23/10 | Groupe | Extensions E1 et E2 | Les plus démontrables, indépendantes du code applicatif |
| | | | |

## Difficultés rencontrées et solutions

| Date | Auteur | Difficulté | Comment elle a été levée |
|---|---|---|---|
| 23/10 | PORGO | Premier `vagrant up` : la version `202404.23.0` de `bento/ubuntu-24.04` donnée dans le squelette de l'énoncé n'est pas publiée pour virtualbox/amd64 (« no available version that matches the constraints ») | Épinglage sur `202510.26.0`, la plus récente des versions publiées (202510.26.0, 202508.03.0, 202502.21.0, 202404.26.0), identique pour tout le groupe |
| 23/10 | PORGO | L'exportateur Prometheus de HAProxy n'était activé que sur lb2 : `haproxy -vv \| grep -q` échoue de façon **aléatoire** sous `set -o pipefail` (grep ferme le tube, haproxy reçoit SIGPIPE) | Sortie de `haproxy -vv` capturée dans une variable, puis test `+PROMEX` ; vérifié sur lb1 et lb2 (406 métriques) |
| 23/10 | PORGO | L'interface privée s'appelle `eth1` sur la box bento, et non `enp0s8` comme supposé dans les exemples | Rien à corriger : l'interface est détectée à partir de l'IP, jamais écrite en dur |
| 23/10 | PORGO | V6 : le 1er script calculait la « reprise » depuis le lancement de `vagrant halt` (11,9 s), alors que lb1 sert encore pendant son arrêt propre : chiffre faux | Mesure de l'interruption réelle (dernier 200 avant la panne → premier 200 après) : 1,68 s puis 1,73 s. Les deux fichiers bruts sont conservés |
| 23/10 | PORGO | R2 : bdd1 a cessé de répondre en SSH (« timeout during server version negotiating ») avec 1,8 Go de RAM libre sur l'hôte | `vagrant reload bdd1`, puis R2 rejoué : 6/6 identiques. Leçon : pendant le développement, `E2_OBS=0` et ne pas lancer d'autres applications lourdes |
| 23/10 | PORGO | Sous Git Bash, `vagrant upload fichier /tmp/x` envoyait vers un chemin Windows (conversion automatique des chemins par MSYS) | Préfixer par `MSYS_NO_PATHCONV=1` (ajouté au dépannage du README) |
| | | | |
