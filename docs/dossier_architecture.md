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

### 2.1 Vue d'ensemble

Le client (navigateur, `curl`, `ab`) s'adresse à une **IP virtuelle** `192.168.59.5` portée par l'un
des deux répartiteurs HAProxy (lb1 actif, lb2 passif), qui se la transmettent par VRRP (keepalived).
Le répartiteur distribue les requêtes, en tourniquet, aux N serveurs applicatifs sans état ; ceux-ci lisent
la base PostgreSQL primaire bdd1, répliquée en flux vers bdd2. La machine obs collecte les métriques
(extension E2). Le schéma est celui du README.

| Machine | IP | RAM | Rôle | Statut |
|---|---|---|---|---|
| (IP virtuelle) | 192.168.59.5 | – | Adresse du service, portée par lb1 ou lb2 | E1 |
| lb1 | 192.168.59.11 | 512 Mo | HAProxy 2.8 + keepalived, actif (priorité 150) | obligatoire |
| lb2 | 192.168.59.12 | 512 Mo | HAProxy 2.8 + keepalived, passif (priorité 100) | E1 |
| app1 … appN | 192.168.59.21 … .2N | 512 Mo | Service HTTP sans état, port 3000 | obligatoire |
| bdd1 | 192.168.59.31 | 768 Mo | PostgreSQL primaire | obligatoire |
| bdd2 | 192.168.59.32 | 768 Mo | Réplique en flux, promouvable | obligatoire |
| obs | 192.168.59.41 | 768 Mo | Prometheus + Grafana | E2 |

Socle obligatoire : 5 VM, 3 072 Mo. Avec E1 et E2 : 4 352 Mo.

### 2.2 Plan d'adressage

Depuis VirtualBox 6.1.28, les réseaux hôte-seul ne sont autorisés par défaut que dans
`192.168.56.0/21`. Le groupe 04 utilise donc `192.168.(55+4).0/24 = 192.168.59.0/24`, sans toucher
à `/etc/vbox/networks.conf` (ce qui rendrait le dépôt non reproductible). Les dizaines codent le rôle :
`.1x` répartition, `.2x` applications, `.3x` données, `.4x` supervision, `.5` IP virtuelle.
`NB_APP` est donc borné à 9 (`.21` à `.29`) pour ne jamais empiéter sur les bases.

### 2.3 Source unique de vérité (R3)

La table `NOEUDS` du `Vagrantfile` est la **seule** description de l'infrastructure. À chaque commande
`vagrant`, elle est sérialisée dans `config/plateforme.json` (et `config/noeuds.yml`), que les VM lisent
dans `/vagrant/config/` via `scripts/plateforme.py`. En découlent automatiquement :
la configuration HAProxy (liste des serveurs), keepalived (pairs VRRP, interface, IP virtuelle),
`/etc/hosts` de chaque machine et les cibles Prometheus. **Aucune adresse n'est écrite en dur** dans
un script ou une configuration.

### 2.4 Cloisonnement réseau (R8)

Tout le trafic interne passe par le réseau privé `192.168.59.0/24`. Le seul port redirigé vers l'hôte est
`127.0.0.1:8080 → lb1:80` (lié à la boucle locale : invisible depuis le réseau de la salle). Les ports
SSH (2222, 2200…) sont ceux que Vagrant ajoute pour son propre accès. La page de statistiques HAProxy
(`:8404`) n'écoute que sur l'IP privée du répartiteur.

## 3. Justification des choix

### 3.1 Répartition : HAProxy (PORGO)

| Besoin | Réponse HAProxy | Pourquoi pas Nginx |
|---|---|---|
| R4 : n'envoyer du trafic qu'aux serveurs sains | **Sonde active** `GET /sante` toutes les secondes (`option httpchk`, `http-check expect status 200`) | Nginx libre ne fait que des contrôles **passifs** (il découvre la panne sur une requête d'utilisateur) ; les sondes actives sont réservées à Nginx Plus |
| V2 : aucune erreur visible quand un serveur tombe | `retry-on conn-failure empty-response response-timeout` + `option redispatch` : la requête est rejouée sur un autre serveur | Possible (`proxy_next_upstream`) mais sans sonde active |
| R3 : ajouter des serveurs sans coupure | `systemctl reload` : nouveau processus, connexions en cours conservées | Équivalent |
| Observer la répartition | En-tête `X-Serveur`, page de stats, exportateur Prometheus intégré (`+PROMEX`) | Statistiques limitées en version libre |

**Calcul du délai d'éviction (R4).** `inter 1s` (une sonde par seconde), `fall 2` (deux échecs
consécutifs). Pour une sonde, HAProxy borne la **connexion** par `timeout connect` (1 s) et la **lecture**
de la réponse par `timeout check` (3 s). Pire cas pour une panne franche (VM éteinte, service arrêté,
connexion refusée) : 1 s (attente de la sonde) + 2 × 1 s ≈ 3 s, donc moins de 5 s. **Mesuré : 1,04 s avec
l'application de test, 1,39 s avec l'application finale** (§ 6). `rise 2` évite qu'un serveur instable soit
réintégré sur un seul succès.

**Pourquoi 3 s de lecture et non 1 s** (correction du 23/10, trouvée au test d'intégration de la bascule) :
après la bascule, bdd1 est éteinte et libpq essaie d'abord bdd1 avant bdd2, si bien que `/sante` répond
200 en 0,6 à 2,1 s. Avec `timeout check 1s`, la sonde déclarait ces serveurs **sains** hors service
(`L7TOUT`) et le service restait en 503 après une bascule pourtant réussie. **Compromis assumé** : un
serveur *gelé* (qui accepte la connexion mais ne répond plus) serait écarté en 1 + 2 × 3 ≈ 7 s au pire, au-delà
des 5 s ; ce cas n'entre pas dans les scénarios V2/V4, et le rejeu `retry-on response-timeout` protège tout de
même les requêtes des utilisateurs. Le détour par l'hôte éteint ne dure que jusqu'à la remise en service de
bdd1 comme réplique (§ 5.3) : `/sante` répond alors en 0,33 s.

La configuration est **engendrée** par `scripts/generer_config_lb.py` puis validée par `haproxy -c`
**avant** d'être installée : une erreur arrête le provisionnement au lieu de casser un répartiteur en service.

### 3.2 Application sans état, connexion multi-hôtes `target_session_attrs` (KOBENDE)

Le service (`app/app.py`, 87 lignes) n'utilise que la bibliothèque standard (`ThreadingHTTPServer`) et
`psycopg2`, installé par apt (`python3-psycopg2`) : aucun `pip`, donc aucun téléchargement imprévisible
pendant le provisionnement.

| Besoin | Choix dans l'application | Pourquoi |
|---|---|---|
| R3 / V2 : n'importe quel serveur peut répondre | **Aucun état** : ni session, ni fichier, ni compteur ; une connexion à la base par requête, toujours refermée (`finally`) | HAProxy peut envoyer chaque requête, ou la rejouer, sur n'importe quel serveur ; ajouter ou perdre un serveur ne perd aucune donnée |
| V4 : survivre à la bascule de la base sans rien modifier | `host=<bdd1>,<bdd2>` et `target_session_attrs=read-write` | libpq essaie les hôtes dans l'ordre et ne garde que celui qui **accepte les écritures**. Avant la bascule, c'est bdd1 ; bdd1 éteinte, bdd2 encore réplique est refusée, donc `/sante` = 503 ; après `pg_promote()`, la même chaîne trouve bdd2 et `/sante` repasse à 200, sans redémarrer l'application |
| R4 : la sonde de HAProxy doit dire la vérité | `/sante` exécute un vrai `SELECT 1` ; 200 seulement s'il réussit | Un serveur dont la base est perdue est retiré de la répartition au lieu de renvoyer des erreurs aux utilisateurs |
| Réponse rapide même si la base est morte | `connect_timeout=2` et `statement_timeout=2000` | Une requête n'attend jamais indéfiniment : la sonde reçoit sa réponse sous les 5 s exigées (503 mesuré en 2,1 s sans base) |
| Pas de trace brute visible | Toute `psycopg2.Error` devient un JSON `503` ; requête SQL paramétrée (`%s`) | Erreurs propres pour l'utilisateur ; protection contre l'injection SQL sur le matricule |
| Démarrer avant la base | La connexion n'est ouverte qu'à la requête | Le service démarre même si bdd1 n'est pas prête : il répond 503 puis 200 dès que la base est là |

**Déploiement** (`scripts/app.sh`) : `app.py` est copié dans `/opt/resultats-bf/` (on n'exécute jamais
depuis le dossier synchronisé `/vagrant`). La configuration `/etc/resultats-bf/app.env` est construite
avec `plateforme ip bdd1` / `plateforme ip bdd2` (aucune adresse en dur, R3) et `$PG_MDP_APP` venu du
`.env` (aucun secret versionné, R7) ; elle est en mode **600**, propriété de root : systemd la lit avant de
lancer le service. Le service systemd `resultats-app` tourne sous un **utilisateur système dédié**, non
root, avec `ProtectSystem=strict`, et `Restart=always` le relance en 1 s s'il s'arrête. Chaque fichier
passe par `installer_si_change` : le service n'est redémarré que si `app.py`, `app.env` ou l'unité ont
réellement changé, ce qui rend le script idempotent (R2).

### 3.3 PostgreSQL et réplication en flux, choix asynchrone et son RPO (OUEDRAOGO)

> Rédigé par PORGO à partir des scripts d'OUEDRAOGO (`bdd.sh`, `replique.sh`) ; à relire par OUEDRAOGO.

| Besoin | Choix | Pourquoi |
|---|---|---|
| Un volume de données réaliste pour les mesures | Table `resultats(matricule PK, nom, serie, moyenne, admis)`, **50 000 lignes** engendrées par `generate_series` (matricules `BF000001` à `BF050000`, moyenne déterministe entre 0 et 20) | Même jeu de données à chaque reconstruction (R1) ; insertion en `ON CONFLICT DO NOTHING` : rejouable (R2) |
| R5 : une seconde copie toujours à jour | **Réplication physique en flux** (`pg_basebackup -R -X stream` depuis bdd1) | Mécanisme natif de PostgreSQL 16, sans logiciel supplémentaire ; bdd2 est une copie exacte, promouvable par `pg_promote()` |
| Choix asynchrone | Réglage par défaut (`synchronous_standby_names` vide) | Une écriture n'attend pas bdd2 : bdd1 reste disponible même si bdd2 tombe. Le prix est un **RPO non nul** : les dernières transactions non encore transmises sont perdues si bdd1 tombe. Mesuré : une écriture sur le primaire est lue sur la réplique moins d'une seconde après (§ 5.3). Pour RÉSULTATS-BF, l'application ne fait que **lire** des données chargées au provisionnement : le RPO effectif est nul |
| Sécurité des accès | `pg_hba.conf` engendré : `app_resultats` (SELECT seulement) et `replicateur` (REPLICATION) acceptés uniquement depuis `192.168.59.0/24`, en `scram-sha-256` ; mots de passe passés par l'environnement | Moindre privilège ; aucun secret dans le dépôt (R7) ; aucun accès extérieur au réseau privé (R8) |
| Durabilité | Données dans `/var/lib/postgresql/16/main`, **jamais** dans `/vagrant` | Le dossier synchronisé de VirtualBox ne garantit ni les verrous ni `fsync` (piège connu de l'énoncé) |
| Ne jamais écraser une base à jour | Garde-fous : `replique.sh` ne recopie que si bdd2 n'a pas encore la base ; `bdd.sh` n'écrit rien sur une réplique | Le provisionnement reste rejouable même après une bascule (§ 5.3) |

### 3.4 Haute disponibilité du répartiteur : VRRP avec keepalived (PORGO)

Un répartiteur unique est un point de défaillance unique. lb1 et lb2 exécutent la même configuration
HAProxy ; keepalived (2.2.8) leur fait partager l'IP virtuelle `192.168.59.5` par VRRP :

- **Priorités** 150 (lb1) et 100 (lb2), engendrées depuis l'ordre de la table ; annonce toutes les secondes
  (`advert_int 1`). Si lb2 n'entend plus lb1 pendant ≈ 3 annonces, il prend l'IP et émet un ARP gratuit
  pour que l'hôte mette à jour son cache.
- **Suivi de HAProxy** (`vrrp_script` + `systemctl is-active haproxy`) : une machine dont HAProxy est
  arrêté abandonne l'IP, même si elle est allumée.
- **Unicast** (`unicast_peer`) plutôt que multicast : aucune dépendance au comportement du réseau hôte-seul.
- **Les deux en `BACKUP` avec `preempt_delay 10`** : au retour de lb1, il attend 10 s (HAProxy prêt) avant de
  reprendre l'IP ; vérifié (§ 6).
- Mot de passe VRRP lu dans `.env` (8 caractères maximum, limite de keepalived), fichier en mode 600.

L'IP virtuelle, et non `localhost:8080`, est l'adresse du service : la redirection de port de Vagrant passe
par la carte NAT de lb1 et disparaît avec lui.

### 3.5 Observabilité : Prometheus + Grafana (THIOMBIANO)

L'exportateur Prometheus intégré à HAProxy est déjà actif sur `http://<ip lb>:8404/metrics` (PORGO).

### 3.6 Points de défaillance unique supprimés, et ceux qui restent (tous)

| Composant | Avant | Après |
|---|---|---|
| Répartiteur | lb1 seul | lb1 + lb2, IP virtuelle VRRP (E1) |
| Serveur applicatif | — | N ≥ 2, sonde de santé, rejeu des requêtes |
| Base de données | bdd1 seule | bdd1 + réplique en flux bdd2, bascule chronométrée (≈ 3 s), réintégration automatique de l'ancien primaire |

**Points de défaillance qui restent** : la bascule de la base est **manuelle** (il faut lancer
`bascule_bdd.sh`) ; l'hôte physique unique (toutes les VM sur un seul ordinateur) ; le réseau hôte-seul
unique ; la machine de supervision obs (sa perte n'interrompt pas le service).

## 4. Reproductibilité et qualité (PORGO)

- **R1, reconstruction.** Sur un clone neuf, `vagrant up` suffit : le `.env` absent est créé à partir de
  `.env.exemple` avec des mots de passe aléatoires (`SecureRandom`), la box est épinglée
  (`bento/ubuntu-24.04` `202510.26.0`), et tout le reste est installé par les scripts. Premier `vagrant up`
  du socle mesuré : **1 433 s** (téléchargement de la box inclus) ; reconstruction complète
  (`vagrant destroy -f && vagrant up`, bases, application et répartiteurs) : **1 934 s**.
- **R2, idempotence.** Trois techniques : `installer_paquets` n'appelle apt que pour les paquets absents ;
  `installer_si_change` n'écrase un fichier (et ne recharge le service) que si son contenu a changé ;
  `/etc/hosts` est un bloc entre marqueurs réécrit à l'identique, jamais un `>>`. Vérifié par empreintes
  SHA-256 avant et après un second `vagrant provision` sur les 6 machines (§ 6).
- **R7, secrets.** Aucun mot de passe dans le dépôt : `.env` est ignoré par Git ; les valeurs passent aux
  scripts par l'option `env:` du provisionneur ; les fichiers qui les contiennent dans les VM sont en mode 600.
- **Fins de ligne.** `.gitattributes` impose LF : un script CRLF échouerait dans la VM (`bash\r`).
- **Connexion lente.** Un seul appel apt par script ; index rafraîchi au plus toutes les 6 h ;
  `DPkg::Lock::Timeout=300` absorbe le verrou d'unattended-upgrades au démarrage.

## 5. Procédures d'exploitation

### 5.1 Ajouter (ou retirer) des serveurs applicatifs (PORGO)

1. Mettre `NB_APP=4` dans `.env` (ou préfixer la commande : `NB_APP=4 vagrant up`).
2. `vagrant up` : Vagrant crée app3 et app4 (provisionnées par `app.sh`), puis rejoue le rôle des
   répartiteurs (`run: "always"`), qui réengendrent `haproxy.cfg` et rechargent HAProxy sans coupure.
3. Contrôle : `http://192.168.59.11:8404/stats` montre 4 serveurs UP.

Pour revenir à 2 : `NB_APP=4 vagrant destroy -f app3 app4`, remettre `NB_APP=2`, puis `vagrant up`.
Les deux sens ont été exécutés (§ 6).

### 5.2 Bascule de la base : `bascule_bdd.sh`, étapes et durée (OUEDRAOGO)

> Rédigé par PORGO à partir du script d'OUEDRAOGO et des mesures ; à relire par OUEDRAOGO.

**Quand ?** bdd1 (primaire) est tombée : `/sante` renvoie 503 sur tous les serveurs applicatifs et HAProxy
renvoie un 503 JSON (`{"erreur": "aucun serveur applicatif disponible"}`), jamais une page blanche.

**Commande** (depuis l'hôte, à la racine du dépôt) :

```bash
time vagrant ssh bdd2 -c "sudo bash /vagrant/scripts/bascule_bdd.sh"
```

**Étapes du script** :

1. **Vérifier que l'ancien primaire est vraiment hors service** (tentative de connexion TCP de 2 s sur son
   port 5432). S'il répond encore, la promotion est **annulée** : promouvoir bdd2 à côté d'un bdd1 vivant
   créerait deux primaires.
2. **Promouvoir** bdd2 : `SELECT pg_promote(true, 60)` (seulement si elle est encore en récupération,
   donc rejouable sans effet).
3. **Attendre** que `pg_is_in_recovery()` renvoie `false` (120 s au maximum, sinon échec explicite).
4. **Afficher** l'heure de début, l'heure de fin et la durée.

Rien n'est à modifier côté application : sa chaîne de connexion `host=bdd1,bdd2 target_session_attrs=read-write`
trouve d'elle-même le nouveau primaire. Le script est symétrique : lancé sur bdd1, il la promeut à la place de bdd2.

**Mesures** :

| Mesure | Résultat | Fichier brut |
|---|---|---|
| Durée de la promotion (script) | **2 s** (OUEDRAOGO), puis **3 s** à chaque test d'intégration (PORGO) | `bdd_20261023.log`, `integration_bascule_20261023_164927.log`, `reintegration_bdd1_20261023_173638.log` |
| Retour du service après la fin de la bascule | **5,1 s** : HAProxy attend 2 sondes réussies (`rise 2`, `downinter 2s`) | `integration_bascule_20261023_164927.log` |
| Commande complète vue de l'hôte | ≈ 10 s, dont ≈ 7 s d'établissement de la session `vagrant ssh` | idem |

**Après la bascule** : remettre bdd1 en service (§ 5.3).

### 5.3 Remise en service de bdd1 comme nouvelle réplique (PORGO, pour OUEDRAOGO)

**Le problème.** Après une bascule, bdd2 est primaire. Quand on rallume bdd1, systemd relance PostgreSQL
**en primaire** : il y a deux primaires (« cerveau divisé »). Comme la chaîne de connexion des applications
essaie bdd1 en premier, elles liraient l'ancienne base, à laquelle il manque tout ce qui a été écrit depuis la
panne. Deuxième danger : rejouer `replique.sh` sur bdd2 promue l'aurait **effacée** pour la recopier depuis
l'ancien primaire.

**La procédure : une seule commande, `vagrant up bdd1`.** Le provisionneur `reintegrer`
(`scripts/reintegrer_bdd.sh`, rejoué à chaque `vagrant up` des deux bases) fait le travail :

1. Si la machine est déjà une réplique (`standby.signal`), ou si l'autre base est injoignable, il ne fait rien.
2. Il compare les **lignes de temps** PostgreSQL : la sienne (`pg_controldata`) et celle de l'autre base
   (commande de réplication `IDENTIFY_SYSTEM`). Chaque promotion incrémente la ligne de temps : si l'autre
   est plus récente, cette machine est l'ancien primaire.
3. Dans ce seul cas : arrêt de PostgreSQL, effacement des données périmées, `pg_basebackup -R` depuis
   le nouveau primaire, redémarrage en réplique, et vérification que le flux est bien reçu (`streaming`).

Le script est **symétrique** (il sert aussi si bdd2 tombe à son tour), comme `bascule_bdd.sh`, qui promeut
désormais la machine où on le lance. Deux garde-fous complètent la procédure : `bdd.sh` n'écrit plus rien si
bdd1 est réplique, et `replique.sh` refuse de réinitialiser bdd2 si elle contient déjà la base (promue).

**Mesures** (fichier `reintegration_bdd1_*.log`) :

| Étape | Résultat |
|---|---|
| État nominal, `--provision-with reintegrer` sur bdd1 | « primaire à jour (ligne de temps 1, bdd2 : 1) » : rien fait |
| Bascule (`halt bdd1` puis `bascule_bdd.sh` sur bdd2) | 3 s |
| Écriture sur bdd2 pendant que bdd1 est éteinte | ligne `REPRISE01` insérée |
| `vagrant up bdd1` | ancien primaire détecté (ligne de temps 1 < 2), **converti en réplique en 39 s** ; commande complète 208 s (démarrage de la VM compris) |
| Données | `REPRISE01` présente sur bdd1 ; nouvelle écriture sur bdd2 lue sur bdd1 1 s après ; 50 002 lignes de chaque côté |
| Service | `/sante` 200 en 0,33 s (contre ≈ 2 s tant que bdd1 était éteinte : libpq écarte vite une réplique joignable) |
| R2 après bascule | `vagrant provision` ×2 sur bdd1 (réplique) et bdd2 (primaire) : 4 × code 0, aucune écriture, aucune réinitialisation |

**Limite connue, mesurée.** Entre le démarrage de la VM et le passage du provisionneur, bdd1 tourne en
primaire périmé pendant **42,7 s** (journal systemd : démarrage 17:41:07,3, arrêt 17:41:50,1). Pendant
cette fenêtre, une application peut lire des données périmées ; elle ne peut pas créer d'écritures
divergentes, car le service est en lecture seule. Amélioration possible : une condition de démarrage
systemd (`ExecStartPre`) sur PostgreSQL qui fasse la même comparaison des lignes de temps **avant** de
démarrer, ce qui fermerait la fenêtre.

### 5.4 Panne et retour d'un répartiteur (PORGO)

- **Panne de lb1** : rien à faire. lb2 prend l'IP virtuelle en moins de 2 s (mesuré).
- **Retour** : `vagrant up lb1`. Le rôle est rejoué (sans changement), keepalived redémarre ; 10 s plus tard
  lb1 reprend l'IP (priorité supérieure). Vérification : `vagrant ssh lb1 -c "ip -4 addr show eth1"` montre
  `192.168.59.5`.
- **Panne de HAProxy seul** sur lb1 (machine allumée) : le `vrrp_script` la détecte et l'IP passe à lb2.
  Mesuré : `systemctl stop haproxy` sur lb1, lb2 entre en état MASTER **2,59 s** plus tard (journal
  keepalived, horloges des deux VM), le service reste joignable (200) ; au redémarrage de HAProxy, lb1
  reprend l'IP.

## 6. Résultats des scénarios (THIOMBIANO + responsables)
Pour chaque scénario : **commande exacte**, **résultat brut** (renvoi au fichier de `tests/resultats/`), **tableau**, **commentaire honnête**.

| Scénario | Mesure attendue | Résultat | Fichier brut |
|---|---|---|---|
| V1 répartition | écart < 20 % | | |
| V2 panne app1 | requêtes perdues, durée dégradée | **0 perdue, 0 dégradée sur 81** (app1 répond jusqu'à 13,1 s après l'ordre d'arrêt, puis app2 seul) — mesure de PORGO avec le script de KOBENDE | `v2_20261023_163047.log` |
| V3 charge N=2 / N=4 | req/s | | |
| V4 panne bdd1 | durée de la bascule | *Test d'intégration (PORGO)* : `/sante` en **503 JSON** pendant la panne ; `bascule_bdd.sh` **3 s** ; service rétabli **5,1 s** après la fin de la bascule, sans redémarrer l'application. Mesure officielle V4 : THIOMBIANO | `integration_bascule_20261023_164927.log` |
| V5 reconstruction | durée totale | | |
| V6 panne lb1 | temps de reprise VRRP | **Application finale : 1 requête perdue sur 124, interruption réelle 1,70 s.** Application de test : 1/122 en 1,73 s, 1/130 en 1,68 s | `v6_20261023_163244.log`, `v6_20261023_104601.log`, `v6_20261023_104251.log` |

Commande V6 : `DUREE=45 bash tests/v6_panne_lb.sh` (une requête vers `http://192.168.59.5/info` toutes les
200 ms, `vagrant halt lb1` à t = 5 s). **Commentaire** : `vagrant halt` éteint lb1 proprement en une dizaine de
secondes, pendant lesquelles il sert encore ; la seule requête perdue tombe dans l'instant où keepalived
s'arrête sur lb1 et où lb2 n'a pas encore pris l'IP. L'interruption mesurée (≈ 1,7 s) est inférieure aux 5 s
exigées, et cohérente avec `advert_int 1` (lb2 n'attend pas l'expiration des annonces : keepalived envoie
une annonce de priorité 0 en s'arrêtant). Une coupure brutale (arrêt électrique) attendrait au contraire
l'expiration des annonces (3 × `advert_int` + décalage ≈ 3 à 4 s), ce qui reste sous les 5 s.

**Vérifications du domaine réseau et répartition** (`bash tests/verifier_repartition.sh r2|r3|r4|r8`) :

| Exigence | Méthode | Résultat | Fichier brut |
|---|---|---|---|
| R1 | `vagrant destroy -f && vagrant up`, plateforme complète (bases, application, répartiteurs), sans aucune commande ensuite | succès, **1 934 s** (box déjà en cache) ; 1er `vagrant up` du socle seul : 1 433 s téléchargement de la box inclus | — (journal de la console) |
| R2 | `vagrant provision` ×2 sur les 6 VM, empreintes SHA-256 des fichiers de configuration (socle, HAProxy, keepalived, application, PostgreSQL) **et PID des services** | **6/6 identiques** sur la plateforme complète | `repartition_20261023_162550.log` (socle seul : `repartition_20261023_105608.log`) |
| R3 | `NB_APP=4` puis stats HAProxy et 20 appels à `/info` | 4 serveurs UP, **5/5/5/5** ; retour à 2 exécuté | `repartition_20261023_110244.log` |
| R4 | arrêt du service de app1, scrutation des stats toutes les 200 ms | application finale : **1 394 ms**, puis **1 279 ms** après le passage à `timeout check 3s` (application de test : 1 037 ms) ; exigence < 5 000 ms | `repartition_20261023_162950.log`, `repartition_20261023_165028.log`, `repartition_20261023_104215.log` |
| R8 | `vagrant port` sur chaque VM | seul lb1 : 80 → 8080 ; ailleurs SSH Vagrant uniquement | `repartition_20261023_104842.log` |
| V1 (préliminaire) | 20 appels à `/info` sur l'IP virtuelle, N = 2 | **10/10**, écart 0 %, avec l'application de test puis avec l'application finale (alternance stricte app1/app2) | — (mesure officielle : THIOMBIANO, `v1_repartition.sh`) |

Les premières mesures (matin du 23/10) ont été faites avec une **application de test temporaire** (15 lignes,
répond 200 sur toutes les routes) ; R1, R2, R4, V2 et V6 ont été **refaites l'après-midi avec l'application
finale et la base répliquée** : ce sont les chiffres de référence. L'application finale a aussi été vérifiée
sur tous ses cas de réponse via l'IP virtuelle : 200 (matricule existant, dont `BF050000`), 400 (paramètre
absent), 404 (matricule ou route inconnus) ; une tentative d'injection SQL (`BF000001' OR 1=1--`) renvoie 404.

Poste de mesure : Intel Core i7-1165G7 (4 cœurs, 8 threads), 15,7 Go de RAM, Windows 11 Professionnel,
VirtualBox 7.2.6, Vagrant 2.4.9 ; VM Ubuntu 24.04.3 LTS (noyau 6.8), HAProxy 2.8.30, keepalived 2.2.8.

## 7. Limites connues et ce que nous ferions autrement (tous)

| Limite | Conséquence | Ce que nous ferions autrement |
|---|---|---|
| Toutes les VM partagent le processeur d'un seul ordinateur | Ajouter des serveurs ne multiplie pas le débit (V3) : les mesures de charge mesurent surtout le partage du CPU | Répartir les VM sur plusieurs hôtes, ou mesurer dans un vrai cloud |
| Bascule de la base **manuelle** | Le service reste en 503 jusqu'à ce qu'un humain lance `bascule_bdd.sh` | Bascule automatique avec Patroni + etcd (consensus, pas de double primaire) |
| Réplication **asynchrone** | Perte possible des dernières transactions (RPO > 0) si l'application écrivait | Réplication synchrone (`synchronous_standby_names`) avec une 3e base pour ne pas bloquer les écritures |
| Fenêtre de **42,7 s** au retour de l'ancien primaire (§ 5.3) | Lectures possiblement périmées pendant cette fenêtre | Condition `ExecStartPre` sur PostgreSQL, ou Patroni |
| Serveur applicatif **gelé** écarté en ≈ 7 s (`timeout check 3s`, § 3.1) | Au-delà des 5 s pour ce cas précis (les pannes franches restent à ≈ 1,3 s) | Une sonde `/sante` plus rapide, qui n'essaie que les bases joignables |
| La box `bento/ubuntu-24.04` est amd64 | Impossible de faire tourner la plateforme sur un Mac à processeur ARM (cas d'un membre du groupe) | Prévoir une box arm64 et un fournisseur adapté (ex. VMware Fusion, Parallels) |
| Une connexion à la base par requête | Coût de connexion à chaque requête (acceptable à notre échelle) | Petit pool de connexions qui se reconnecte, ou PgBouncer |

## 8. Annexes

### 8.1 Arborescence du dépôt

```
Vagrantfile                  table NOEUDS = source unique de vérité
.env.exemple                 modèle de configuration (le .env n'est jamais versionné)
app/app.py                   service HTTP sans état (87 lignes)
scripts/lib.sh               fonctions communes (apt groupé, idempotence, attente)
scripts/plateforme.py        lecture de config/plateforme.json
scripts/commun.sh            socle de toutes les machines
scripts/lb.sh                HAProxy + keepalived
scripts/generer_config_lb.py haproxy.cfg et keepalived.conf engendrés
scripts/app.sh               déploiement du service applicatif
scripts/bdd.sh               PostgreSQL primaire et jeu de données
scripts/replique.sh          réplique en flux
scripts/bascule_bdd.sh       promotion chronométrée
scripts/reintegrer_bdd.sh    remise en service de l'ancien primaire
scripts/obs.sh               Prometheus + Grafana (E2)
tests/                       scénarios V1 à V6, vérifications, résultats bruts
docs/                        plan de travail, installation, dossier, journal
```

### 8.2 Extrait de la configuration HAProxy engendrée (N = 2)

```
defaults
    retries 2
    retry-on conn-failure empty-response response-timeout
    timeout connect 1s
    timeout check   3s
    default-server inter 1s fastinter 500ms downinter 2s fall 2 rise 2

backend serveurs_applicatifs
    balance roundrobin
    option httpchk
    http-check send meth GET uri /sante
    http-check expect status 200
    server app1 192.168.59.21:3000 check
    server app2 192.168.59.22:3000 check
```

Avec `NB_APP=4`, les lignes `server app3 …` et `server app4 …` apparaissent seules, sans autre modification.
