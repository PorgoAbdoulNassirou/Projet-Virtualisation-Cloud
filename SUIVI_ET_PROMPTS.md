# RÉSULTATS-BF : suivi du travail, ordre de passage et prompts

**Groupe 04**, réseau `192.168.59.0/24`. **Rendu : lundi 26 octobre 2026.**
Dépôt : `https://github.com/PorgoAbdoulNassirou/Projet-Virtualisation-Cloud.git`

Ce fichier dit **ce qui est fait, par qui**, **qui travaille avant qui**, et donne à chacun le
**prompt à coller dans son Claude** (Claude Code, ouvert dans son clone du dépôt) pour continuer.
Le détail des tâches et des contrats est dans [docs/PLAN_DE_TRAVAIL.md](docs/PLAN_DE_TRAVAIL.md).

---

## 1. Ce qui est fait

| Élément | Fichiers | Fait par | État |
|---|---|---|---|
| Plan d'adressage, table des machines (source unique de vérité), `NB_APP` paramétrable | `Vagrantfile` | PORGO Abdoul Nassirou | ✅ validé en VM |
| Secrets : `.env` auto-généré, `.env.exemple`, `.gitignore`, `.gitattributes` (LF) | racine | PORGO Abdoul Nassirou | ✅ validé en VM |
| Bibliothèque commune, lecture de `plateforme.json`, socle commun idempotent | `scripts/lib.sh`, `scripts/plateforme.py`, `scripts/commun.sh` | PORGO Abdoul Nassirou | ✅ validé en VM |
| HAProxy engendré, sonde `/sante` (< 5 s), rejeu des requêtes, statistiques | `scripts/lb.sh`, `scripts/generer_config_lb.py` | PORGO Abdoul Nassirou | ✅ validé en VM |
| Extension E1 : lb2 + keepalived, IP virtuelle `192.168.59.5` | `scripts/lb.sh`, `scripts/generer_config_lb.py` | PORGO Abdoul Nassirou | ✅ validé en VM |
| Scénario V6 (panne du répartiteur) : 1 requête perdue / 122, interruption 1,73 s | `tests/v6_panne_lb.sh` | PORGO Abdoul Nassirou | ✅ mesuré |
| Vérification R2 (6/6 identiques), R3 (4 serveurs, 5/5/5/5), R4 (1 037 ms), R8 | `tests/verifier_repartition.sh`, `tests/resultats/` | PORGO Abdoul Nassirou | ✅ mesuré |
| Sections 2, 3.1, 3.4, 4, 5.1, 5.4 et mesures du dossier, journal de bord | `docs/dossier_architecture.md`, `docs/journal_de_bord.md` | PORGO Abdoul Nassirou | ✅ rédigé |
| README, plan de travail, modèles du dossier et du journal | `README.md`, `docs/` | PORGO Abdoul Nassirou | ✅ écrit |
| Squelettes et contrats des autres rôles | `scripts/bdd.sh`, `replique.sh`, `bascule_bdd.sh`, `app.sh`, `obs.sh`, `app/README.md`, `tests/README.md` | PORGO Abdoul Nassirou | ✅ squelettes, **à remplir** |

> ✅ **Jalon J1 atteint le 23/10** : `vagrant up` complet réussi sur le poste de PORGO (box `bento/ubuntu-24.04`
> **202510.26.0** : la version 202404.23.0 de l'énoncé n'existe pas). Le répartiteur a été testé avec une
> application de test temporaire ; HAProxy renverra 503 tant que l'application réelle n'est pas fusionnée,
> c'est normal.

## 2. Ce qui reste à faire, et par qui

| Membre | Rôle | Reste à faire |
|---|---|---|
| **PORGO Abdoul Nassirou** | Architecte réseau et répartition | Inviter les membres, relire/fusionner les PR, rejouer V6 et R4 avec l'application finale, R1 sur le poste d'un autre membre |
| **OUEDRAOGO Armand Hendrix** | Ingénieur données | `bdd.sh`, `replique.sh`, `bascule_bdd.sh` (R5, R6, V4) ; rotation sur `app/app.py` |
| **KOBENDE Pêgdwendé Evrard** | Ingénieur applicatif | `app/app.py`, `scripts/app.sh` ; rotation `tests/v2_panne_app.sh` |
| **THIOMBIANO Yempabou Romaric Johan** | Ingénieur essais et observabilité | E2 (`obs.sh`, Grafana), V1, V3, V4, V5, assemblage du dossier et du journal ; rotation node_exporter dans `commun.sh` |

---

## 3. Ordre de passage (qui travaille avant qui)

```
 ÉTAPE 0  PORGO         socle + 1er vagrant up réel (J1)  ✅ FAIT le 23/10
              │
 ÉTAPE 1  OUEDRAOGO     bdd.sh + replique.sh                           ← bloque l'appli et les tests
    ║     KOBENDE       écrit app.py en parallèle (contrat fixé),
    ║                   intègre APRÈS la fusion de feat/bdd
    ║     THIOMBIANO    obs.sh (E2) en parallèle, indépendant
              │
 ÉTAPE 2  KOBENDE       app.sh fusionné → V1/V2 possibles (J2)
          OUEDRAOGO     bascule_bdd.sh → V4 (J3)
          PORGO         relecture des PR, R4 et V6 rejoués avec l'application finale
              │
 ÉTAPE 3  THIOMBIANO    campagne V1 à V5, captures Grafana, dossier
              │
 ÉTAPE 4  TOUS          destroy + up sur un poste vierge, répétition de la démo
```

| Ordre | Qui | Peut commencer | Doit avoir fusionné avant |
|---|---|---|---|
| 0 | PORGO | ✅ fait le 23/10 | ✅ poussé dans `main` |
| 1 | OUEDRAOGO | dès le clone | **sam. 24 midi** (`bdd.sh` + `replique.sh`), dim. 25 midi (bascule) |
| 2 | KOBENDE | dès le clone (écriture) ; intégration après OUEDRAOGO | sam. 24 soir |
| 3 | THIOMBIANO | dès le clone (E2) ; mesures après KOBENDE | dim. 25 soir (mesures), lun. 26 (dossier) |

**Règle d'or : avant de pousser, `vagrant destroy -f && vagrant up` doit passer sur votre poste.**

---

## 4. Préparation commune (à faire par chacun, une seule fois)

1. Installer **VirtualBox 7.x** et la **dernière version de Vagrant 2.4.x**, puis **Git** et **Claude Code**.
2. Configurer Git **avec son propre nom** (l'historique prouve qui a fait quoi) :
   ```bash
   git config --global user.name  "Prénom NOM"
   git config --global user.email "adresse@du.compte.github"
   git config --global core.autocrlf false
   ```
3. Cloner, puis ouvrir Claude Code dans le dossier cloné :
   ```bash
   git clone https://github.com/PorgoAbdoulNassirou/Projet-Virtualisation-Cloud.git resultats-bf
   cd resultats-bf
   ```
4. Pendant le développement, mettre `E1_LB2=0` et `E2_OBS=0` dans `.env` (créé au premier
   `vagrant up`) pour économiser la mémoire. Les remettre à 1 pour les tests finaux.

---

## 5. Prompts à coller dans Claude

Chaque prompt se colle **tel quel** dans Claude Code, ouvert à la racine du dépôt cloné.

### 5.0 PORGO Abdoul Nassirou (étape 0 faite ; suite : intégration)

```text
Tu travailles sur le dépôt RÉSULTATS-BF (projet Vagrant, groupe 04, réseau 192.168.59.0/24).
Je suis PORGO Abdoul Nassirou, architecte réseau et répartition. Ma partie est faite et validée
en VM le 23/10 (J1, R2, R3, R4, R8, V6 : voir tests/resultats/ et docs/dossier_architecture.md § 6).
Lis d'abord SUIVI_ET_PROMPTS.md, docs/PLAN_DE_TRAVAIL.md (fiche 3.1 et contrats § 4), le
Vagrantfile, scripts/lib.sh, scripts/lb.sh, scripts/generer_config_lb.py, tests/verifier_repartition.sh
et tests/v6_panne_lb.sh.

Mon rôle maintenant : intégrateur.
1. Pour chaque pull request des autres membres : vérifier qu'aucune IP n'est écrite en dur
   (toujours `plateforme ip …`), qu'aucun secret n'apparaît dans le diff, que les scripts sont
   idempotents (`vagrant provision <machine>` deux fois) ; me dire ce qui bloque avant que je fusionne.
2. Quand app.py et app.sh de KOBENDE sont fusionnés : `vagrant up`, puis rejouer
   `bash tests/verifier_repartition.sh r4` et `DUREE=45 bash tests/v6_panne_lb.sh` avec
   l'application finale, et mettre à jour les chiffres du § 6 du dossier (garder les fichiers bruts).
3. R1 sur poste vierge : guider un autre membre pour `vagrant destroy -f && vagrant up` sur son poste.
Contraintes : aucune adresse IP en dur, aucun secret dans le dépôt, scripts idempotents, fins de
ligne LF. Sous Git Bash, préfixer `vagrant upload` par MSYS_NO_PATHCONV=1. Commits en français, avec
mon identité Git uniquement : n'ajoute JAMAIS de ligne Co-Authored-By ni aucune mention de Claude
ou d'une IA dans les commits ou les pull requests. Explique-moi chaque décision pour que je puisse
la défendre en soutenance.
```

### 5.1 OUEDRAOGO Armand Hendrix (étape 1, prioritaire)

```text
Tu travailles sur le dépôt RÉSULTATS-BF (projet Vagrant + VirtualBox, groupe 04, réseau
192.168.59.0/24). Je suis OUEDRAOGO Armand Hendrix, ingénieur données. Lis d'abord
SUIVI_ET_PROMPTS.md, docs/PLAN_DE_TRAVAIL.md (fiche 3.3 et contrats § 4, surtout 4.2 et 4.3),
scripts/lib.sh, scripts/plateforme.py, puis les squelettes scripts/bdd.sh, scripts/replique.sh
et scripts/bascule_bdd.sh dont les en-têtes contiennent mon contrat.

Travaille sur une branche feat/bdd et réalise, dans cet ordre :
1. scripts/bdd.sh (bdd1, primaire) : PostgreSQL 16 d'Ubuntu 24.04 via `installer_paquets`
   (un seul appel), listen_addresses='*' dans un fichier de conf.d, pg_hba limité au réseau
   donné par `plateforme valeur reseau` en scram-sha-256 (sans `>>` qui s'accumule), base
   `resultats`, table resultats(matricule text PRIMARY KEY, nom text, serie text,
   moyenne numeric(4,2), admis boolean) peuplée de 50 000 lignes par generate_series
   (matricules BF000001 à BF050000, insertion idempotente), rôle app_resultats (SELECT
   seulement, mot de passe $PG_MDP_APP), rôle replicateur (REPLICATION, $PG_MDP_REPLICATION),
   droits de réplication dans pg_hba pour bdd2.
2. scripts/replique.sh (bdd2) : `attendre_port "$(plateforme ip bdd1)" 5432`, puis
   pg_basebackup -R -X stream SEULEMENT si standby.signal est absent ; même configuration
   réseau que bdd1 pour pouvoir être promue.
3. Vérifier R5 : INSERT sur bdd1 → visible sur bdd2 ; noter la commande exacte et le résultat.
4. scripts/bascule_bdd.sh : vérifier que bdd1 est injoignable, SELECT pg_promote(), attendre
   pg_is_in_recovery() = false, afficher début, fin et durée (R6, scénario V4).
Contraintes : aucune adresse IP en dur (toujours `plateforme ip …`), aucun mot de passe en
clair, données jamais dans /vagrant, idempotence prouvée par `vagrant provision bdd1` et
`vagrant provision bdd2` lancés deux fois de suite sans erreur ni changement. Tester avec
`vagrant destroy -f bdd1 bdd2 && vagrant up bdd1 bdd2`. Mettre E1_LB2=0 et E2_OBS=0 dans .env
pendant le développement. Rotation obligatoire : ensuite, relis app/app.py et améliore la
gestion des erreurs de base (target_session_attrs=read-write, connect_timeout) dans un commit
séparé. Commits en français avec mon identité Git uniquement : n'ajoute JAMAIS de ligne
Co-Authored-By ni aucune mention de Claude ou d'une IA dans les commits ou les pull requests.
Pousse la branche et ouvre une pull request vers main. Explique-moi chaque choix pour que je
puisse le défendre en soutenance.
```

### 5.2 KOBENDE Pêgdwendé Evrard (étape 1 en parallèle, intégration après OUEDRAOGO)

```text
Tu travailles sur le dépôt RÉSULTATS-BF (projet Vagrant + VirtualBox, groupe 04, réseau
192.168.59.0/24). Je suis KOBENDE Pêgdwendé Evrard, ingénieur applicatif. Lis d'abord
SUIVI_ET_PROMPTS.md, docs/PLAN_DE_TRAVAIL.md (fiche 3.2 et contrats § 4), app/README.md
(spécification complète de l'application), scripts/lib.sh, scripts/plateforme.py et le
squelette scripts/app.sh.

Travaille sur une branche feat/app et réalise :
1. app/app.py : Python 3, moins de 100 lignes, uniquement http.server (ThreadingHTTPServer)
   et psycopg2. Points d'entrée : GET /resultat?matricule=… (200 JSON, 400, 404, 503),
   GET /sante (200 seulement si SELECT 1 réussit, 503 sinon, jamais 200 par principe),
   GET /info ({"serveur": nom d'hôte}). Écoute 0.0.0.0:3000. Aucun état (ni session, ni
   fichier, ni compteur). Configuration uniquement par PG_HOTES, PG_BASE, PG_UTIL, PG_MDP.
   Connexion multi-hôtes : host=<bdd1>,<bdd2> … connect_timeout=2 target_session_attrs=read-write.
   Le service démarre même si la base est absente ; toute erreur de base devient un JSON 503 propre.
2. scripts/app.sh : `installer_paquets python3-psycopg2`, copie de app.py vers
   /opt/resultats-bf/, fichier /etc/resultats-bf/app.env en mode 600 construit avec
   `plateforme ip bdd1` / `plateforme ip bdd2` et $PG_MDP_APP, service systemd resultats-app
   (Restart=always, utilisateur non root, EnvironmentFile), redémarrage SEULEMENT si app.py
   ou l'unité a changé (fonction installer_si_change).
3. Tu peux écrire et tester app.py tout de suite. L'intégration complète se fait APRÈS la
   fusion de la branche feat/bdd d'OUEDRAOGO : alors `vagrant up`, et vérifier que
   curl http://192.168.59.5/info alterne entre app1 et app2, et que /sante passe à 503
   quand bdd1 est arrêtée.
Contraintes : aucune adresse IP en dur, aucun secret dans le dépôt, idempotence prouvée par
`vagrant provision app1` lancé deux fois de suite. Mettre E1_LB2=0 et E2_OBS=0 dans .env pendant
le développement. Rotation obligatoire : écris ensuite tests/v2_panne_app.sh (charge continue
de curl sur http://192.168.59.5/info, `vagrant halt app1` au bout de 5 s, nombre de requêtes
perdues et durée de la période dégradée, résultat brut dans tests/resultats/), sur le modèle
de tests/v6_panne_lb.sh. Commits en français avec mon identité Git uniquement : n'ajoute JAMAIS
de ligne Co-Authored-By ni aucune mention de Claude ou d'une IA dans les commits ou les pull
requests. Pousse la branche et ouvre une pull request vers main. Explique-moi chaque ligne
importante pour que je puisse la défendre en soutenance.
```

### 5.3 THIOMBIANO Yempabou Romaric Johan (E2 en parallèle, mesures en dernier)

```text
Tu travailles sur le dépôt RÉSULTATS-BF (projet Vagrant + VirtualBox, groupe 04, réseau
192.168.59.0/24). Je suis THIOMBIANO Yempabou Romaric Johan, ingénieur essais et
observabilité. Lis d'abord SUIVI_ET_PROMPTS.md, docs/PLAN_DE_TRAVAIL.md (fiche 3.4 et
contrats § 4), tests/README.md, tests/v6_panne_lb.sh (modèle de script de scénario),
scripts/lib.sh, scripts/plateforme.py, le squelette scripts/obs.sh et docs/dossier_architecture.md.

Partie A, tout de suite, sur une branche feat/obs (extension E2) :
1. scripts/obs.sh : Prometheus (paquet apt) dont les cibles sont ENGENDRÉES depuis
   /vagrant/config/plateforme.json (node_exporter <ip>:9100 de toutes les machines,
   HAProxy <ip lb>:8404/metrics), aucune adresse en dur. Grafana via le dépôt apt.grafana.com
   ajouté de façon idempotente, mot de passe admin $GRAFANA_MDP, source de données et
   tableau de bord provisionnés par fichiers dans config/grafana/ (débit par serveur,
   serveurs UP/DOWN, CPU par machine). Accès depuis l'hôte : http://192.168.59.41:3000.
2. Rotation obligatoire : dans scripts/commun.sh, activer le bloc node_exporter déjà préparé
   (commit séparé).
Partie B, quand l'application et la base sont fusionnées dans main (branche feat/tests) :
3. tests/v1_repartition.sh (20 appels à /info, comptage par serveur, écart < 20 %),
   tests/v3_montee_charge.sh (ab -n 2000 -c 50 avec NB_APP=2 puis NB_APP=4, requêtes/s),
   tests/v4_panne_bdd.sh (halt bdd1, /sante en 503 propre, bascule chronométrée avec
   scripts/bascule_bdd.sh), tests/v5_reconstruction.sh (durée de destroy -f + up).
   Chaque script s'exécute depuis l'hôte (Git Bash), lit l'IP virtuelle dans
   config/plateforme.json et écrit son résultat brut daté dans tests/resultats/.
4. Remplir docs/dossier_architecture.md (tableau des résultats V1 à V6, captures Grafana
   pendant V2 et V3, caractéristiques du poste) et docs/journal_de_bord.md.
Contraintes : mesures réelles uniquement, jamais inventées ; commenter honnêtement (toutes
les VM partagent un seul processeur, donc doubler N ne double pas le débit). Idempotence de
obs.sh prouvée par `vagrant provision obs` lancé deux fois. Commits en français avec mon
identité Git uniquement : n'ajoute JAMAIS de ligne Co-Authored-By ni aucune mention de Claude
ou d'une IA dans les commits ou les pull requests. Pousse les branches et ouvre des pull
requests vers main. Explique-moi chaque mesure pour que je puisse la défendre en soutenance.
```

---

## 6. Suivi (chacun coche quand sa branche est fusionnée dans `main`)

- [x] **0** PORGO : J1 `vagrant up` réel validé
- [ ] **1** OUEDRAOGO : `bdd.sh` + `replique.sh` fusionnés (R5)
- [ ] **2** KOBENDE : `app.py` + `app.sh` fusionnés (V1, V2 possibles, J2)
- [ ] **2** OUEDRAOGO : `bascule_bdd.sh` fusionné (V4, J3)
- [x] **2** PORGO : R2, R3, R4, R8 vérifiés ; V6 mesuré (à rejouer avec l'application finale)
- [ ] **1** THIOMBIANO : E2 fusionnée
- [ ] **3** THIOMBIANO : V1, V3, V4, V5 mesurés ; dossier assemblé
- [ ] **4** TOUS : `destroy` + `up` sur un poste vierge ; démo répétée ; chacun a lancé chaque scénario
- [ ] **Rotation** : KOBENDE (v2), OUEDRAOGO (app.py), THIOMBIANO (commun.sh), PORGO (v6)
