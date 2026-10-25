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
| PostgreSQL primaire, 50 000 lignes, réplication en flux, bascule chronométrée (R5 vérifiée, R6 : 2 s) | `scripts/bdd.sh`, `scripts/replique.sh`, `scripts/bascule_bdd.sh`, `tests/resultats/bdd_20261023.log` | OUEDRAOGO Armand Hendrix | ✅ fusionné |
| Service HTTP sans état (`/resultat`, `/sante`, `/info`), déploiement systemd, scénario V2 (0 requête perdue) | `app/app.py`, `scripts/app.sh`, `tests/v2_panne_app.sh` | KOBENDE Pêgdwendé Evrard | ✅ fusionné, testé en VM par PORGO |
| Test d'intégration complet (R1 1 934 s, R2 6/6, R4 1,3 s, V6 1,70 s, bascule de base) et correctif `timeout check 3s` | `scripts/generer_config_lb.py`, `tests/resultats/` | PORGO Abdoul Nassirou | ✅ mesuré |
| Remise en service de bdd1 après bascule (§ 5.3) : réintégration automatique en réplique, garde-fous `bdd.sh` / `replique.sh`, bascule symétrique | `scripts/reintegrer_bdd.sh`, `Vagrantfile`, `scripts/bdd.sh`, `scripts/replique.sh`, `scripts/bascule_bdd.sh` | PORGO Abdoul Nassirou (pour OUEDRAOGO) | ✅ testé : réplique en 39 s, R2 après bascule OK |
| Extension E2 : Prometheus (cibles engendrées), Grafana (tableau de bord provisionné), node_exporter partout ; idempotence vérifiée | `scripts/obs.sh`, `config/grafana/`, `scripts/commun.sh`, `Vagrantfile` (rôle obs `run: always`) | THIOMBIANO Yempabou Romaric Johan | ✅ testé en VM, branche `feat/obs` + `feat/tests` |
| Scénarios V1, V3, V4, V5 et mesures (V1 0 %, V2 0/139 et 0/132, V3 15,7 → 12,3 réponses 200/s, V4 bascule 3 s, V5 1 778 s), captures C1 à C6b | `tests/v1…v5_*.sh`, `tests/resultats/`, `docs/captures/` | THIOMBIANO Yempabou Romaric Johan | ✅ mesuré le 24/10, branche `feat/tests` |
| Squelettes et contrats des autres rôles | `scripts/bdd.sh`, `replique.sh`, `bascule_bdd.sh`, `app.sh`, `obs.sh`, `app/README.md`, `tests/README.md` | PORGO Abdoul Nassirou | ✅ squelettes, **à remplir** |

> ✅ **Jalon J1 atteint le 23/10** : `vagrant up` complet réussi sur le poste de PORGO (box `bento/ubuntu-24.04`
> **202510.26.0** : la version 202404.23.0 de l'énoncé n'existe pas). Le répartiteur a été testé avec une
> application de test temporaire ; HAProxy renverra 503 tant que l'application réelle n'est pas fusionnée,
> c'est normal.

## 2. Ce qui reste à faire, et par qui

| Membre | Rôle | Reste à faire |
|---|---|---|
| **PORGO Abdoul Nassirou** | Architecte réseau et répartition | ✅ branches de THIOMBIANO fusionnées, rapport et journal mis en forme pour le rendu (PDF), fiche de démonstration. Reste : **envoyer** (§ 7) et répéter la démo |
| **OUEDRAOGO Armand Hendrix** | Ingénieur données | ✅ partie fusionnée ; ✅ rotation faite le 25/10 (`tests/verifier_replication.sh`, R5 vérifiée sur deux postes) |
| **KOBENDE Pêgdwendé Evrard** | Ingénieur applicatif | ✅ partie fusionnée et testée. Reste : préparer la soutenance (`docs/DEMONSTRATION.md`) |
| **THIOMBIANO Yempabou Romaric Johan** | Ingénieur essais et observabilité | ✅ E2, V1, V3, V4, V5, rapport assemblé ; branches fusionnées dans `main` le 25/10 |

---

## 3. Ordre de passage (qui travaille avant qui)

```
 ÉTAPE 0  PORGO         socle + 1er vagrant up réel (J1)  ✅ FAIT le 23/10
              │
 ÉTAPE 1  OUEDRAOGO     base, réplication, bascule        ✅ FAIT le 23/10
 ÉTAPE 2  KOBENDE       application + V2                  ✅ FAIT le 23/10
          PORGO         intégration, correctifs, R4/V6, remise en service de bdd1  ✅ FAIT le 23/10
              │
 ÉTAPE 3  THIOMBIANO    E2, campagne V1, V3, V4, V5, captures Grafana, rapport   ← MAINTENANT
              │
 ÉTAPE 4  TOUS          destroy + up sur un poste vierge, répétition de la démo
```

| Ordre | Qui | Peut commencer | Doit avoir fusionné avant |
|---|---|---|---|
| 0 | PORGO | ✅ fait le 23/10 | ✅ poussé dans `main` |
| 1 | OUEDRAOGO | ✅ fait le 23/10 | ✅ fusionné dans `main` (base, réplication, bascule) |
| 2 | KOBENDE | ✅ fait le 23/10 | ✅ fusionné dans `main` et testé en VM |
| 3 | THIOMBIANO | **maintenant** (tout ce dont il dépend est dans `main`) | dim. 25 soir (mesures), lun. 26 matin (rapport) |

**Règle d'or : avant de pousser, `vagrant destroy -f && vagrant up` doit passer sur votre poste.**

---

## 4. Préparation commune (à faire par chacun, une seule fois)

1. Installer les outils en suivant **[docs/INSTALLATION.md](docs/INSTALLATION.md)** : VirtualBox **7.2.6**,
   Vagrant **2.4.9**, Git, Claude Code (commandes `winget` prêtes à copier). THIOMBIANO installe en plus
   Apache Bench (`ab`) et Pandoc. **Tout nouvel outil ou paquet doit être ajouté à ce guide.**
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

### 5.1 OUEDRAOGO Armand Hendrix (✅ rotation faite le 25/10 ; prompt conservé pour mémoire)

```text
Tu travailles sur le dépôt RÉSULTATS-BF (projet Vagrant + VirtualBox, groupe 04, réseau
192.168.59.0/24). Je suis OUEDRAOGO Armand Hendrix, ingénieur données. Ma partie (bdd.sh,
replique.sh, bascule_bdd.sh) est fusionnée, mais je n'ai encore AUCUN commit hors de mon domaine :
l'énoncé rend la rotation obligatoire et l'historique Git fait foi. Commence par `git pull`, puis
lis SUIVI_ET_PROMPTS.md, tests/README.md, tests/v6_panne_lb.sh et tests/v1_repartition.sh (modèles
de scripts de scénario), scripts/bdd.sh, scripts/replique.sh, scripts/reintegrer_bdd.sh et
docs/dossier_architecture.md (§ 3.3, 5.2, 5.3).

Tâche (domaine des tests, hors du mien) : écrire tests/r5_replication.sh, lancé DEPUIS L'HÔTE (Git
Bash) à la racine du dépôt, qui prouve l'exigence R5 :
1. détecter quelle base est primaire et laquelle est réplique (pg_is_in_recovery() sur chacune,
   par `vagrant ssh bddN -c "sudo -u postgres psql -tAc ..."`), sans rien supposer ;
2. insérer une ligne de test datée sur le primaire, mesurer le délai jusqu'à ce qu'elle soit
   lisible sur la réplique (scrutation toutes les 200 ms), puis la supprimer ;
3. afficher et enregistrer le résultat brut dans tests/resultats/r5_<date>.log ;
4. ajouter la ligne du script au tableau de tests/README.md, et la mesure au § 6 du dossier
   (tableau « Vérifications ») ; ajouter dans docs/journal_de_bord.md, ligne « Rôles », la mention
   « test R5 par OUEDRAOGO » dans la liste des commits hors domaine.
Si je ne peux pas lancer les VM, écris et vérifie au moins la syntaxe (`bash -n`) et indique-le ;
PORGO lancera la mesure. Contraintes : aucune adresse IP en dur (lire config/plateforme.json),
aucun secret. Commits en français avec mon identité Git uniquement : n'ajoute JAMAIS de ligne
Co-Authored-By ni aucune mention de Claude ou d'une IA dans les commits ou les pull requests.
Pousse sur une branche feat/r5 et préviens PORGO pour la fusion.
```

### 5.2 KOBENDE Pêgdwendé Evrard (partie fusionnée et testée)

```text
Tu travailles sur le dépôt RÉSULTATS-BF (projet Vagrant + VirtualBox, groupe 04). Je suis KOBENDE
Pêgdwendé Evrard, ingénieur applicatif. Ma partie (app/app.py, scripts/app.sh, tests/v2_panne_app.sh)
est fusionnée et a été testée en VM par PORGO (V2 : 0 requête perdue sur 81). Mon poste est un Mac
M2 : la box amd64 n'y tourne pas, je ne peux pas lancer les VM. Commence par `git pull`, puis lis
SUIVI_ET_PROMPTS.md, docs/dossier_architecture.md en entier et docs/journal_de_bord.md.
Prépare-moi pour la soutenance, où l'enseignant peut m'interroger sur n'importe quelle partie :
explique-moi le rôle de chaque script, le correctif `timeout check 3s` de HAProxy (§ 3.1) et la
remise en service de bdd1 (§ 5.3), puis pose-moi 10 questions de soutenance et corrige mes réponses.
Ne modifie aucun fichier sans me le demander.
```

### 5.3 THIOMBIANO Yempabou Romaric Johan (C'EST SON TOUR : E2, mesures, rapport)

```text
Tu travailles sur le dépôt RÉSULTATS-BF (projet Vagrant + VirtualBox, groupe 04, réseau
192.168.59.0/24, IP virtuelle 192.168.59.5). Je suis THIOMBIANO Yempabou Romaric Johan, ingénieur
essais et observabilité. Tout le reste est fusionné dans main et testé : réseau et répartition
(PORGO), base répliquée et bascule (OUEDRAOGO), application (KOBENDE). Commence par `git pull`, puis
lis SUIVI_ET_PROMPTS.md, docs/INSTALLATION.md, docs/PLAN_DE_TRAVAIL.md (fiche 3.4 et contrats § 4),
tests/README.md, tests/v6_panne_lb.sh et tests/v2_panne_app.sh (modèles de scripts de scénario),
scripts/lib.sh, scripts/plateforme.py, scripts/commun.sh, le squelette scripts/obs.sh,
docs/dossier_architecture.md et docs/journal_de_bord.md.

Faits utiles déjà établis (ne pas les redécouvrir) :
- Premier `vagrant up` complet : ≈ 25 à 32 min. Vérifier d'abord docs/INSTALLATION.md
  (VirtualBox 7.2.6, Vagrant 2.4.9, processeur Intel/AMD : un Mac ARM ne fait pas tourner la box).
- HAProxy expose déjà ses métriques Prometheus sur http://192.168.59.11:8404/metrics (et .12) et sa
  page de statistiques sur /stats ; il ajoute l'en-tête X-Serveur sur chaque réponse.
- L'application répond en JSON SANS retour à la ligne final : pour compter les serveurs, utiliser
  l'en-tête X-Serveur ou ajouter un echo après chaque curl.
- Sous Git Bash : préfixer `vagrant upload` par MSYS_NO_PATHCONV=1.
- Après NB_APP=4, mettre NB_APP=4 dans .env (sinon les commandes suivantes ne voient plus app3/app4).
- Bascule : `vagrant ssh bdd2 -c "sudo bash /vagrant/scripts/bascule_bdd.sh"` ; ensuite
  `vagrant up bdd1` la remet en service comme réplique (automatique, voir dossier § 5.3).
- Mesures déjà faites (dossier § 6) : R1 1 934 s, R2 6/6, R3 5/5/5/5, R4 1,28 s, V2 0 perdue / 81,
  V6 1,70 s, bascule 3 s puis service rétabli 5,1 s après.

Partie A (branche feat/obs) : extension E2.
1. scripts/obs.sh : Prometheus (paquet apt) dont les cibles sont ENGENDRÉES depuis
   /vagrant/config/plateforme.json (node_exporter <ip>:9100 de toutes les machines, HAProxy
   <ip lb>:8404/metrics), aucune adresse en dur ; Grafana via le dépôt apt.grafana.com ajouté de
   façon idempotente, mot de passe admin $GRAFANA_MDP, source de données et tableau de bord
   provisionnés par fichiers dans config/grafana/ (débit par serveur, serveurs UP/DOWN, CPU).
   Accès depuis l'hôte : http://192.168.59.41:3000. Ajouter les paquets à docs/INSTALLATION.md § 4.
2. Rotation obligatoire : activer le bloc node_exporter déjà préparé dans scripts/commun.sh
   (commit séparé).
3. Idempotence : `vagrant provision obs` deux fois sans changement ; puis
   `bash tests/verifier_repartition.sh r2`.
Partie B (branche feat/tests) : scénarios, depuis l'hôte (Git Bash), résultat brut daté dans
tests/resultats/ pour chacun :
4. tests/v1_repartition.sh (20 appels, comptage par serveur, écart < 20 %),
   tests/v3_montee_charge.sh (ab -n 2000 -c 50 sur http://192.168.59.5/resultat?matricule=BF000123
   avec NB_APP=2 puis NB_APP=4 ; requêtes/s),
   tests/v4_panne_bdd.sh (halt bdd1, /sante en 503 propre, bascule chronométrée, retour à 200, puis
   `vagrant up bdd1` et vérification qu'elle est redevenue réplique),
   tests/v5_reconstruction.sh (durée de destroy -f + up).
5. Captures Grafana pendant V2 et V3 (débit qui monte, serveur qui disparaît).
Partie C : rapport.
6. Remplir docs/dossier_architecture.md : § 1 (contexte), § 3.5 (observabilité), § 6 (V1, V3, V4,
   V5 : commande exacte, résultat brut, tableau, commentaire honnête : toutes les VM partagent un
   seul processeur, doubler N ne double pas le débit), et compléter docs/journal_de_bord.md.
7. Produire le rendu : pandoc docs/dossier_architecture.md -o dossier_architecture.docx
   (10 à 15 pages) et vérifier la mise en page.
Contraintes : mesures réelles uniquement, jamais inventées ; aucune IP en dur, aucun secret,
idempotence. Commits en français avec mon identité Git uniquement : n'ajoute JAMAIS de ligne
Co-Authored-By ni aucune mention de Claude ou d'une IA dans les commits ou les pull requests.
Pousse les branches et ouvre des pull requests vers main. Explique-moi chaque mesure pour que je
puisse la défendre en soutenance.
```

---

## 6. Suivi (chacun coche quand sa branche est fusionnée dans `main`)

- [x] **0** PORGO : J1 `vagrant up` réel validé
- [x] **1** OUEDRAOGO : `bdd.sh` + `replique.sh` fusionnés (R5) — 23/10
- [x] **2** KOBENDE : `app.py` + `app.sh` fusionnés (V2 mesuré : 0 perdue / 81) — 23/10
- [x] **2** OUEDRAOGO : `bascule_bdd.sh` fusionné (bascule mesurée : 2 s) — 23/10
- [x] **2** PORGO : R2, R3, R4, R8 vérifiés ; V6 rejoué avec l'application finale (1,70 s)
- [x] **1** THIOMBIANO : E2 fusionnée dans `main` le 25/10
- [x] **3** THIOMBIANO : V1, V3, V4, V5 mesurés le 24/10 (branche `feat/tests`) ; § 1, 3.5 et 6 du dossier rédigés
- [x] **3** THIOMBIANO / PORGO : dossier final assemblé, en-tête de rendu, converti en Word et PDF (15 pages) le 25/10
- [ ] **4** TOUS : `destroy` + `up` sur un poste vierge ; démo répétée ; chacun a lancé chaque scénario
- [x] **Rotation** : [x] KOBENDE (v2), [x] OUEDRAOGO (verifier_replication.sh), [x] THIOMBIANO (commun.sh), [x] PORGO (v6)

---

## 7. Livrables à rendre le 26 octobre (énoncé, § 8)

| Code | Livrable | Forme | Responsable | Fichier |
|---|---|---|---|---|
| L1 | Dépôt Git | Vagrantfile, scripts/, app/, config/, README.md, .env.exemple ; commits de **chaque** membre | PORGO | ce dépôt |
| L2 | **Dossier d'architecture (le rapport)** | **10 à 15 pages** : contexte, architecture et justification des choix, schéma, procédures d'exploitation, résultats V1 à V6 en tableaux, limites | THIOMBIANO assemble, chacun rédige ses sections | `docs/dossier_architecture.md` → `.docx`/`.pdf` |
| L3 | Journal de bord | **1 à 2 pages** : rôles, décisions et pourquoi, difficultés et solutions | tous | `docs/journal_de_bord.md` |
| L4 | Démonstration | **20 min** sur machine vierge : destruction, reconstruction, 3 scénarios tirés au sort | tous | — |

Conversion pour le rendu, depuis la racine du dépôt (modèle compact `docs/modele_word.docx` : dossier en 15 pages, journal en 2 pages), puis export PDF avec LibreOffice ou Word :

```bash
pandoc docs/dossier_architecture.md --resource-path=docs --reference-doc docs/modele_word.docx -o docs/dossier_architecture.docx
pandoc docs/journal_de_bord.md --reference-doc docs/modele_word.docx -o docs/journal_de_bord.docx
```

### Ce qu'il faut envoyer à l'enseignant

| # | Quoi | Fichier ou lien |
|---|---|---|
| 1 | **Lien du dépôt Git** (L1) | https://github.com/PorgoAbdoulNassirou/Projet-Virtualisation-Cloud (dépôt **public**, ou enseignant invité comme collaborateur s'il est privé) |
| 2 | **Dossier d'architecture** (L2), 15 pages | `docs/dossier_architecture.pdf` (et `docs/dossier_architecture.docx` si un format modifiable est demandé) |
| 3 | **Journal de bord** (L3), 2 pages | `docs/journal_de_bord.pdf` (et `.docx`) |
| 4 | **Démonstration** (L4) | rien à envoyer : en direct, fiche `docs/DEMONSTRATION.md` |

Message type : « Groupe 04 (KOBENDE, PORGO, OUEDRAOGO, THIOMBIANO), projet RÉSULTATS-BF. Dépôt : <lien>.
Ci-joints le dossier d'architecture et le journal de bord. Le README du dépôt suffit pour reconstruire la
plateforme (`vagrant up`). »

**Avant d'envoyer** : (1) ✅ commit de rotation d'OUEDRAOGO fusionné ; (2) vérifier que le dépôt est
accessible à l'enseignant ; (3) ne jamais joindre le fichier `.env`.
