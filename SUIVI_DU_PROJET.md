# RÉSULTATS-BF : suivi du projet

Groupe 04, réseau `192.168.59.0/24`. Rendu le lundi 26 octobre 2026.
Dépôt : https://github.com/PorgoAbdoulNassirou/Projet-Virtualisation-Cloud

Ce fichier nous a servi à suivre l'avancement : ce qui a été fait, par qui, et dans quel ordre.
Le détail des tâches et des contrats entre les rôles se trouve dans [docs/PLAN_DE_TRAVAIL.md](docs/PLAN_DE_TRAVAIL.md).

## 1. Travail réalisé

| Élément | Fichiers | Réalisé par | État |
|---|---|---|---|
| Plan d'adressage, table des machines (source unique), `NB_APP` paramétrable | `Vagrantfile` | PORGO Abdoul Nassirou | validé en VM |
| Secrets : `.env` créé au premier lancement, `.env.exemple`, `.gitignore`, `.gitattributes` | racine | PORGO Abdoul Nassirou | validé en VM |
| Bibliothèque commune, lecture de `plateforme.json`, socle commun idempotent | `scripts/lib.sh`, `scripts/plateforme.py`, `scripts/commun.sh` | PORGO Abdoul Nassirou | validé en VM |
| HAProxy généré, sonde `/sante`, rejeu des requêtes, statistiques | `scripts/lb.sh`, `scripts/generer_config_lb.py` | PORGO Abdoul Nassirou | validé en VM |
| Extension E1 : lb2 et keepalived, IP virtuelle `192.168.59.5` | `scripts/lb.sh`, `scripts/generer_config_lb.py` | PORGO Abdoul Nassirou | validé en VM |
| Scénario V6 (panne du répartiteur) et vérifications R2, R3, R4, R8 | `tests/v6_panne_lb.sh`, `tests/verifier_repartition.sh` | PORGO Abdoul Nassirou | mesuré |
| PostgreSQL primaire, 50 000 lignes, réplication en flux, bascule | `scripts/bdd.sh`, `scripts/replique.sh`, `scripts/bascule_bdd.sh` | OUEDRAOGO Armand Hendrix | fusionné |
| Vérification de la réplication (R5) | `tests/verifier_replication.sh` | OUEDRAOGO Armand Hendrix | mesuré sur deux postes |
| Service HTTP sans état (`/resultat`, `/sante`, `/info`), service systemd | `app/app.py`, `scripts/app.sh` | KOBENDE Pêgdwendé Evrard | fusionné et testé en VM |
| Scénario V2 (panne d'un serveur applicatif) | `tests/v2_panne_app.sh` | KOBENDE Pêgdwendé Evrard | mesuré |
| Tests d'intégration et réglage `timeout check 3s` | `scripts/generer_config_lb.py`, `tests/resultats/` | PORGO Abdoul Nassirou | mesuré |
| Remise en service de bdd1 comme réplique après une bascule | `scripts/reintegrer_bdd.sh`, `Vagrantfile` | PORGO Abdoul Nassirou | testé |
| Extension E2 : Prometheus, Grafana, node_exporter | `scripts/obs.sh`, `config/grafana/`, `scripts/commun.sh` | THIOMBIANO Yempabou Romaric Johan | testé en VM |
| Scénarios V1, V3, V4, V5, captures | `tests/v1` à `v5`, `tests/resultats/`, `docs/captures/` | THIOMBIANO Yempabou Romaric Johan | mesuré |
| Dossier d'architecture et journal de bord | `docs/` | tous, assemblage par THIOMBIANO et PORGO | terminé |

## 2. Ordre de passage

| Étape | Qui | Travail | Date |
|---|---|---|---|
| 0 | PORGO | Socle réseau, répartition, premier `vagrant up` complet | 23/10 |
| 1 | OUEDRAOGO | Base de données, réplication, bascule | 23/10 |
| 2 | KOBENDE | Application et scénario V2 | 23/10 |
| 2 | PORGO | Intégration, correctifs, R4 et V6 avec l'application finale, remise en service de bdd1 | 23/10 |
| 3 | THIOMBIANO | Supervision (E2), scénarios V1, V3, V4, V5, captures, assemblage du dossier | 24/10 et 25/10 |
| 4 | Tous | Reconstruction complète, répétition de la démonstration | 25/10 |

Règle commune : avant de pousser, `vagrant destroy -f && vagrant up` devait passer sur le poste de la personne.

## 3. Préparation du poste

1. Installer les outils décrits dans [docs/INSTALLATION.md](docs/INSTALLATION.md) : VirtualBox 7.2.6,
   Vagrant 2.4.9 et Git. Pour les mesures, Apache Bench (`ab`) et Pandoc.
2. Configurer Git avec son propre nom, puisque l'historique montre qui a fait quoi :
   ```bash
   git config --global user.name  "Prénom NOM"
   git config --global user.email "adresse@du.compte.github"
   git config --global core.autocrlf false
   ```
3. Cloner le dépôt :
   ```bash
   git clone https://github.com/PorgoAbdoulNassirou/Projet-Virtualisation-Cloud.git resultats-bf
   cd resultats-bf
   ```
4. Pendant le développement, mettre `E1_LB2=0` et `E2_OBS=0` dans `.env` pour économiser la mémoire,
   puis les remettre à 1 pour les tests finaux.

## 4. Points de contrôle

- [x] PORGO : premier `vagrant up` complet validé (23/10)
- [x] OUEDRAOGO : base et réplique fusionnées (23/10)
- [x] KOBENDE : application fusionnée, V2 mesuré (23/10)
- [x] OUEDRAOGO : bascule fusionnée (23/10)
- [x] PORGO : R2, R3, R4, R8 vérifiés, V6 rejoué avec l'application finale
- [x] THIOMBIANO : E2 fusionnée (25/10)
- [x] THIOMBIANO : V1, V3, V4, V5 mesurés (24/10)
- [x] Dossier et journal convertis en Word et PDF (25/10)
- [x] Travail hors domaine : KOBENDE (V2), OUEDRAOGO (R5), THIOMBIANO (`commun.sh`), PORGO (V6)
- [ ] Tous : démonstration répétée, chacun ayant lancé chaque scénario

## 5. Livrables

| Code | Livrable | Fichier |
|---|---|---|
| L1 | Dépôt Git | ce dépôt |
| L2 | Dossier d'architecture, 15 pages | `docs/dossier_architecture.pdf` (et `.docx`) |
| L3 | Journal de bord, 2 pages | `docs/journal_de_bord.pdf` (et `.docx`) |
| L4 | Démonstration de 20 minutes | en direct, voir `docs/DEMONSTRATION.md` |

Le fichier `.env` n'est jamais versionné ni envoyé.
