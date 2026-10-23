# Dossier d'architecture : RÉSULTATS-BF

> Livrable L2, 10 à 15 pages. Assemblage : THIOMBIANO. Chaque section indique son rédacteur.
> Convertir en PDF pour le rendu (`pandoc dossier_architecture.md -o dossier_architecture.pdf`).

**Groupe 04 (réseau 192.168.59.0/24) — Membres :** KOBENDE Pêgdwendé Evrard, PORGO Abdoul Nassirou,
OUEDRAOGO Armand Hendrix, THIOMBIANO Yempabou Romaric Johan

---

## 1. Contexte et exigences (THIOMBIANO)
- Le problème : site de résultats qui tombe au moment de la publication.
- Les deux exigences non fonctionnelles : résilience et scalabilité. Leur traduction en choix d'architecture.

## 2. Architecture (PORGO)
- Schéma (reprendre celui du README) et inventaire des machines (IP, RAM, rôle).
- Plan d'adressage : pourquoi `192.168.(55+G).0/24` (contrainte VirtualBox ≥ 6.1.28).
- Source unique de vérité : table `NOEUDS` → `config/plateforme.json` → HAProxy, keepalived, hosts, Prometheus.
- Cloisonnement réseau (R8) : seul lb1 expose 127.0.0.1:8080.

## 3. Justification des choix
- 3.1 Répartition : HAProxy (sonde HTTP active, rejeu des requêtes, rechargement sans coupure, stats) (PORGO)
- 3.2 Application sans état, multi-hôtes `target_session_attrs` (KOBENDE)
- 3.3 PostgreSQL et réplication en flux, choix asynchrone et son RPO (OUEDRAOGO)
- 3.4 Haute disponibilité du répartiteur : VRRP / keepalived (PORGO)
- 3.5 Observabilité : Prometheus + Grafana (THIOMBIANO)
- 3.6 Points de défaillance unique supprimés, et ceux qui restent (tous)

## 4. Reproductibilité et qualité (PORGO)
- R1 reconstruction, R2 idempotence (technique `installer_si_change`), R7 secrets (`.env` auto-généré).

## 5. Procédures d'exploitation
- 5.1 Ajouter un serveur applicatif : `NB_APP=4 vagrant up` (PORGO)
- 5.2 Bascule de la base : `bascule_bdd.sh`, étapes et durée (OUEDRAOGO)
- 5.3 Remise en service de bdd1 comme nouvelle réplique (OUEDRAOGO)
- 5.4 Panne et retour d'un répartiteur (PORGO)

## 6. Résultats des scénarios (THIOMBIANO + responsables)
Pour chaque scénario : **commande exacte**, **résultat brut** (renvoi au fichier de `tests/resultats/`), **tableau**, **commentaire honnête**.

| Scénario | Mesure attendue | Résultat | Fichier brut |
|---|---|---|---|
| V1 répartition | écart < 20 % | | |
| V2 panne app1 | requêtes perdues, durée dégradée | | |
| V3 charge N=2 / N=4 | req/s | | |
| V4 panne bdd1 | durée de la bascule | | |
| V5 reconstruction | durée totale | | |
| V6 panne lb1 | temps de reprise VRRP | | |

Poste de mesure : processeur …, RAM …, système …, versions de VirtualBox et Vagrant ….

## 7. Limites connues et ce que nous ferions autrement (tous)
- Toutes les VM partagent un seul processeur physique : limite des mesures de charge.
- Bascule de la base manuelle (pas de Patroni), réplication asynchrone.
- …

## 8. Annexes
- Arborescence du dépôt, extraits de configuration engendrée (`haproxy.cfg`, `keepalived.conf`).
