# RÉSULTATS-BF : plan de travail et répartition des rôles

**Projet de groupe, Virtualisation et Cloud Computing, M1 Informatique IBAM (Dr SOMDA)**
**Rendu : 26 octobre 2026.** Ce document est la référence commune du groupe : chacun y trouve
ce qu'il doit faire, les fichiers dont il est responsable, et les contrats à respecter avec les autres.

---

## 1. Ce qui est évalué (à garder en tête en permanence)

L'application est minuscule exprès. **Ce qui est noté, c'est l'infrastructure, et la preuve chiffrée
qu'elle tient.**

| Critère | Points | Exigences |
|---|---|---|
| Reconstruction intégrale | 4 | R1 : `vagrant destroy -f && vagrant up`, zéro geste manuel |
| Scalabilité | 3 | R3 : `NB_APP=4 vagrant up`, configuration du répartiteur engendrée |
| Résilience | 4 | R4 (sonde `/sante`, < 5 s), R5 (réplication), R6 (bascule chronométrée) |
| Qualité technique | 2 | R2 (idempotence), R7 (aucun secret), R8 (réseau privé) |
| Extensions | 2 | **E1** (lb2 + VRRP) et **E2** (Prometheus + Grafana) |
| Dossier et mesures | 3 | Scénarios V1 à V6 : commande exacte, résultat brut, commentaire |
| Démonstration | 2 | **Chacun doit savoir expliquer TOUTES les parties** |

**Pénalités à éviter absolument :**
- `vagrant up` qui échoue sur une machine vierge → **note plafonnée à 8/20** ;
- mesures inventées → −4 ;
- adresses des applications en dur dans HAProxy → −2 ;
- mot de passe dans l'historique Git → −2.

---

## 2. Répartition des rôles

| Membre | Rôle | Domaine | Extension |
|---|---|---|---|
| **PORGO Abdoul Nassirou** | Architecte réseau et répartition | Plan d'adressage, Vagrantfile, socle commun, HAProxy, sonde de santé, dépôt Git | **E1** |
| **KOBENDE Pêgdwendé Evrard** | Ingénieur applicatif | Service HTTP sans état, gestion des erreurs de base, déploiement des applications | E4 (bonus) |
| **OUEDRAOGO Armand Hendrix** | Ingénieur données | PostgreSQL, 50 000 lignes, réplication, procédure de bascule | E3 (bonus) |
| **THIOMBIANO Yempabou Romaric Johan** | Ingénieur essais et observabilité | Scénarios V1 à V6, mesures, Prometheus/Grafana, assemblage du dossier | **E2** |

> Les deux extensions obligatoires retenues sont **E1** et **E2** : ce sont les plus démontrables, et
> elles sont indépendantes du code applicatif. E3 (Redis) et E4 (déploiement sans coupure) ne sont à
> faire **que si** tout le socle passe et que le temps le permet.

**Rotation obligatoire** : chaque membre fait au moins **un commit significatif hors de son domaine**
(l'historique Git fait foi). Les commits prévus sont indiqués dans chaque fiche.

---

## 3. Fiches individuelles

### 3.1 PORGO Abdoul Nassirou : architecte réseau et répartition

**Fichiers dont il est responsable :** `Vagrantfile`, `.env.exemple`, `.gitignore`, `.gitattributes`,
`scripts/lib.sh`, `scripts/plateforme.py`, `scripts/commun.sh`, `scripts/lb.sh`,
`scripts/generer_config_lb.py`, `README.md`.

**Déjà réalisé (dans ce dépôt) :**
- [x] Plan d'adressage `192.168.(55+G).0/24` et table `NOEUDS`, **source unique de vérité**
      engendrant `config/plateforme.json` et `config/noeuds.yml` ;
- [x] `NB_APP` paramétrable (2 à 9), réglé dans `.env` ou dans le shell (`NB_APP=4 vagrant up`) ;
- [x] `.env` créé automatiquement avec des mots de passe aléatoires (R1 et R7) ;
- [x] seul lb1 expose un port (`127.0.0.1:8080` → 80) (R8) ;
- [x] socle commun idempotent : apt groupé, fuseau horaire, `/etc/hosts` engendré ;
- [x] HAProxy engendré depuis `plateforme.json`, sonde `GET /sante` toutes les secondes,
      serveur écarté après 2 échecs (≈ 2 à 3 s, donc < 5 s) (R4) ;
- [x] rejeu des requêtes sur un autre serveur en cas de panne (`retry-on`, `redispatch`), pour V2 ;
- [x] rechargement de HAProxy sans coupure, et seulement si la configuration change (R2) ;
- [x] E1 : keepalived sur lb1/lb2, IP virtuelle `.5`, VRRP unicast, suivi de l'état de HAProxy ;
- [x] statistiques HAProxy et métriques Prometheus sur `http://<ip lb>:8404` (réseau privé) ;
- [x] script du scénario V6 (`tests/v6_panne_lb.sh`), **commit hors domaine**.

**Validé sur de vraies VM le 23/10 (mesures dans `tests/resultats/`) :**
- [x] dépôt GitHub créé et poussé ;
- [x] **J1** : `vagrant up` complet réussi (1 433 s, téléchargement de la box inclus) ;
- [x] R2 : `vagrant provision` ×2 sur les 6 VM → empreintes identiques ;
- [x] R3 : `NB_APP=4` → 4 serveurs UP, répartition 5/5/5/5 ; retour à 2 exécuté ;
- [x] R4 : serveur défaillant écarté en 1 037 ms ;
- [x] R8 : seul lb1 expose un port (80 → 8080) ;
- [x] V6 : 1 requête perdue sur 122, interruption réelle 1,73 s ; panne de HAProxy seul → lb2 maître en 2,59 s ;
- [x] script de vérification `tests/verifier_repartition.sh` (R2, R3, R4, R8) ;
- [x] dossier : sections 2, 3.1, 3.4, 4, 5.1, 5.4 et mesures du § 6 rédigées.

**Reste à faire :**
- [ ] inviter les 3 membres comme collaborateurs du dépôt GitHub ;
- [x] relire et fusionner les pull requests des autres (vérifier : aucune IP en dur, aucun secret) ;
- [x] **rejouer V6 et R4 avec l'application finale** de KOBENDE (fait : V6 1,70 s, R4 1,28 s) ;
- [ ] `vagrant destroy -f && vagrant up` sur le poste d'un autre membre (R1 sur poste vierge ; fait sur le poste de PORGO : 1 934 s).
- [x] test d'intégration complet et correctifs : `timeout check 3s` (bascule bloquée en 503), remise en service de bdd1 après bascule (`reintegrer_bdd.sh`, § 5.3), sections 3.3, 5.2, 7 et 8 du dossier.

**À savoir expliquer en soutenance :** pourquoi la configuration est engendrée (R3), pourquoi
`run: "always"` sur le répartiteur, le calcul du délai de détection (`inter 1s`, `fall 2`,
`timeout check 1s`), la différence entre `localhost:8080` (lb1 seul) et l'IP virtuelle (survit à lb1),
le fonctionnement de VRRP (priorités 150/100, `advert_int 1`, bascule en ≈ 3 s).

---

### 3.2 KOBENDE Pêgdwendé Evrard : ingénieur applicatif

**Fichiers :** `app/app.py`, `scripts/app.sh`. **Spécification complète : `app/README.md`.**

**À faire :**
- [x] `app/app.py` (< 100 lignes, Python 3, `http.server` + `psycopg2`) : `/resultat`, `/sante`, `/info` ;
- [x] `/sante` = vrai `SELECT 1` avec délai court ; 503 si la base ne répond pas ;
- [x] **aucun état** ; erreurs de base transformées en JSON 503 ; démarrage possible sans base ;
- [x] chaîne de connexion multi-hôtes `host=bdd1,bdd2 … target_session_attrs=read-write` ;
- [x] `scripts/app.sh` : `installer_paquets python3-psycopg2`, copie dans `/opt/resultats-bf/`,
      `/etc/resultats-bf/app.env` (mode 600), service systemd `resultats-app` (`Restart=always`,
      utilisateur non root), écoute sur `0.0.0.0:3000` ;
- [x] idempotent : copie et rechargement seulement si `app.py` ou l'unité a changé (`installer_si_change`) ;
- [x] **rotation** : écrire `tests/v2_panne_app.sh` (charge continue + `vagrant halt app1`,
      compte des requêtes perdues, durée de la période dégradée) ;
- [ ] bonus E4 (seulement si tout est vert) : `scripts/deployer.sh`, mise à jour serveur par serveur
      (`disable server` via le socket HAProxy, mise à jour, `enable server`).

**Fini quand :** `curl http://<VIP>/info` alterne entre app1 et app2 ; `/sante` renvoie 503 quand
bdd1 est éteinte, puis 200 après la bascule, sans redémarrer l'application.

---

### 3.3 OUEDRAOGO Armand Hendrix : ingénieur données

**Fichiers :** `scripts/bdd.sh`, `scripts/replique.sh`, `scripts/bascule_bdd.sh`.

**À faire :**
- [x] `bdd.sh` (bdd1) : PostgreSQL 16, `listen_addresses='*'` via `conf.d` (pas de `sed`, pas de `>>`),
      `pg_hba` limité au réseau du groupe, `scram-sha-256` ;
- [x] base `resultats`, table `resultats(matricule PK, nom, serie, moyenne, admis)`,
      **50 000 lignes** par `generate_series`, matricules `BF000001` … `BF050000`, insertion idempotente ;
- [x] rôles `app_resultats` (SELECT) et `replicateur` (REPLICATION), mots de passe
      `$PG_MDP_APP` / `$PG_MDP_REPLICATION` (variables d'environnement, jamais en clair) ;
- [x] `replique.sh` (bdd2) : attendre bdd1, puis `pg_basebackup -R -X stream` **seulement si** la machine
      n'est pas déjà une réplique (`standby.signal`) ;
- [x] vérifier R5 : `INSERT` sur bdd1 → `SELECT` sur bdd2 (noter la commande et le résultat) ;
- [x] `bascule_bdd.sh` : vérification que bdd1 est injoignable, `pg_promote()`, attente de
      `pg_is_in_recovery() = false`, affichage de la durée (R6, V4) ;
- [x] répertoire de données **jamais** dans `/vagrant` ;
- [ ] **rotation** : relire et améliorer la gestion des erreurs de base dans `app/app.py`
      (`target_session_attrs`, délais de connexion) ;
- [ ] bonus E3 (seulement si tout est vert) : Redis devant la base, gain mesuré et discussion de l'invalidation.

**Fini quand :** V4 passe : `/sante` en 503 propre pendant la panne, bascule exécutée et chronométrée,
service rétabli sur bdd2.

---

### 3.4 THIOMBIANO Yempabou Romaric Johan : ingénieur essais et observabilité

**Fichiers :** `tests/*.sh` (sauf v2 et v6), `scripts/obs.sh`, `config/grafana/`,
`docs/dossier_architecture.md` (assemblage).

**À faire :**
- [ ] `v1_repartition.sh` (20 appels à `/info`, comptage par serveur, écart < 20 %) ;
- [ ] `v3_montee_charge.sh` (`ab -n 2000 -c 50` avec N=2 puis N=4, req/s) ;
- [ ] `v4_panne_bdd.sh` (avec OUEDRAOGO) et `v5_reconstruction.sh` (durée totale de `destroy` + `up`) ;
- [ ] tous les résultats bruts dans `tests/resultats/` (versionnés) + caractéristiques du poste ;
- [ ] E2 : `obs.sh` (Prometheus + Grafana), cibles **engendrées** depuis `plateforme.json`,
      tableau de bord provisionné par fichiers (débit, serveurs UP/DOWN, CPU) ;
- [ ] **rotation** : activer node_exporter dans `scripts/commun.sh` (bloc déjà préparé, commenté) ;
- [ ] assembler le dossier (10 à 15 pages) et le journal de bord ; captures Grafana pendant V2 et V3.

**Fini quand :** chaque scénario V1 à V6 a sa commande exacte, son résultat brut et un commentaire
honnête dans le dossier, et le tableau de bord montre le débit monter et un serveur disparaître.

---

## 4. Contrats d'interface (à respecter strictement)

Ces conventions permettent à chacun d'avancer sans attendre les autres. **On ne les change pas sans
prévenir tout le groupe.**

### 4.1 Adresses (groupe 04, réseau `192.168.59.0/24`)

| Machine | IP | RAM | Rôle / script | Port |
|---|---|---|---|---|
| (VIP) | `.5` | – | IP virtuelle VRRP (E1) | 80 |
| lb1 | `.11` | 512 Mo | `lb.sh` (HAProxy actif) | 80, stats 8404 |
| lb2 | `.12` | 512 Mo | `lb.sh` (passif, E1) | 80, stats 8404 |
| app1…appN | `.21`…`.2N` | 512 Mo | `app.sh` | 3000 |
| bdd1 | `.31` | 768 Mo | `bdd.sh` (primaire) | 5432 |
| bdd2 | `.32` | 768 Mo | `replique.sh` | 5432 |
| obs | `.41` | 768 Mo | `obs.sh` (E2) | Grafana 3000, Prometheus 9090 |

Socle obligatoire = 5 VM = 3 072 Mo. Avec E1 + E2 : 4 352 Mo.

### 4.2 Règles pour TOUS les scripts

1. Commencer par `set -euo pipefail` puis `source /vagrant/scripts/lib.sh`.
2. **Ne jamais écrire une adresse IP en dur** : `plateforme ip bdd1`, `plateforme role app`,
   `plateforme valeur reseau`, `plateforme valeur vip`.
3. Paquets : **un seul** appel `installer_paquets p1 p2 p3` par script.
4. Fichiers de configuration : écrire dans un fichier temporaire, puis
   `if installer_si_change "$tmp" /etc/… 644; then systemctl reload …; fi`. **Jamais de `>>`**.
5. Secrets : uniquement par les variables `$PG_MDP_APP`, `$PG_MDP_REPLICATION`, `$VRRP_MDP`,
   `$GRAFANA_MDP` (transmises par le Vagrantfile depuis `.env`). Fichiers qui en contiennent : mode 600.
6. Les services écoutent sur `0.0.0.0` (ou sur l'IP privée), **jamais** sur `127.0.0.1` seul.
7. Pour attendre une machine : `attendre_port "$(plateforme ip bdd1)" 5432 120`.
8. Test d'idempotence avant chaque push : `vagrant provision <machine>` **deux fois** de suite.

### 4.3 Base de données ↔ application

| Élément | Valeur |
|---|---|
| Base | `resultats` |
| Table | `resultats(matricule text PRIMARY KEY, nom text, serie text, moyenne numeric(4,2), admis boolean)` |
| Matricules | `BF000001` … `BF050000` |
| Rôle applicatif | `app_resultats`, SELECT seulement, mot de passe `$PG_MDP_APP` |
| Rôle de réplication | `replicateur`, mot de passe `$PG_MDP_REPLICATION` |
| Connexion | `host=<bdd1>,<bdd2> port=5432 dbname=resultats user=app_resultats connect_timeout=2 target_session_attrs=read-write` |

### 4.4 Application ↔ répartiteur

- HAProxy interroge `GET /sante` sur le port 3000 de chaque app : **200** = en service, sinon écarté.
- HAProxy ajoute l'en-tête `X-Serveur: appN` à chaque réponse (utilisé par V1).

---

## 5. Planning compressé (rendu le 26 octobre)

| Date | Objectif | Qui | Jalon |
|---|---|---|---|
| **Ven. 23 oct.** | Dépôt créé, tous clonent, installent Vagrant + VirtualBox ; socle réseau et répartiteur poussés (PORGO) ; chacun commence son script sur une branche | Tous | **J1** : `vagrant up` fonctionne de bout en bout |
| **Sam. 24 oct.** | `app.py` + `app.sh` (KOBENDE) ; `bdd.sh` + 50 000 lignes + `replique.sh` (OUEDRAOGO) ; V1 et V2 écrits (THIOMBIANO, KOBENDE) | Tous | **J2** : V1 et V2 passent |
| **Dim. 25 oct.** | Bascule + V4 (OUEDRAOGO) ; E1 + V6 (PORGO) ; E2 + V3 (THIOMBIANO) ; **`destroy` + `up` sur le poste d'un autre membre** | Tous | **J3** : V4 passe, E1 et E2 démontrées |
| **Lun. 26 oct.** | V5 sur poste vierge, dossier finalisé, journal de bord, **répétition de la démo à 4** | Tous | **Rendu** |

Règle : au moins **un `vagrant destroy -f && vagrant up` par jour sur un poste différent**.

---

## 6. Livrables

| Code | Livrable | Responsable principal | Contributeurs |
|---|---|---|---|
| L1 | Dépôt Git (Vagrantfile, scripts/, app/, config/, README.md, .env.exemple) | PORGO | tous |
| L2 | Dossier d'architecture, 10 à 15 pages (`docs/dossier_architecture.md` → PDF) | THIOMBIANO | chacun rédige sa partie |
| L3 | Journal de bord, 1 à 2 pages (`docs/journal_de_bord.md`) | THIOMBIANO | tous (une entrée par décision) |
| L4 | Démonstration de 20 min (destruction, reconstruction, 3 scénarios tirés au sort) | tous | chacun sait tout faire |

---

## 7. Règles Git

- Dépôt : `resultats-bf` sur GitHub, branche `main` protégée par convention (pas de push direct sans test).
- Une branche par travail : `feat/app`, `feat/bdd`, `feat/obs`, `feat/lb`…, fusionnée par *pull request*.
- **Chacun commite avec son propre compte** (`git config user.name` / `user.email`) : la rotation est vérifiée sur l'historique.
- Messages clairs en français : `app : sonde /sante renvoie 503 si la base est absente`.
- **Jamais** de `.env`, de mot de passe ni de `config/plateforme.json` dans un commit. Vérifier avec `git status` avant chaque commit.
- Sous Windows, une seule fois : `git config --global core.autocrlf false` (le `.gitattributes` impose LF).

---

## 8. Liste de contrôle finale (à cocher ensemble le 26 au matin)

**Exigences**
- [x] R1 : `vagrant destroy -f && vagrant up` sur un poste vierge, sans aucune commande ensuite
- [x] R2 : `vagrant provision` deux fois, aucun changement et aucune erreur
- [x] R3 : `NB_APP=4 vagrant up`, 4 serveurs dans les stats HAProxy, aucune IP en dur
- [x] R4 : serveur défaillant écarté en moins de 5 s
- [x] R5 : écriture sur bdd1 visible sur bdd2
- [x] R6 : bascule exécutable et chronométrée
- [x] R7 : `git log --all -p -- .env` est vide et `git log --all -p | grep -E 'MDP[A-Z_]*=[^_]'` ne renvoie rien
- [x] R8 : seul lb1 a un `forwarded_port` dans le Vagrantfile

**Scénarios** (commande + résultat brut + commentaire dans le dossier)
- [ ] V1 répartition, [x] V2 panne app, [ ] V3 charge N=2/N=4, [ ] V4 panne bdd, [ ] V5 reconstruction, [x] V6 panne lb

**Soutenance** : chaque membre a lancé lui-même au moins une fois **chaque** scénario.
