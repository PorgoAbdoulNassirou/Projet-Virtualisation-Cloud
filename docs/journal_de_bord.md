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
| | | | |
