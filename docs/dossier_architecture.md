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
même les requêtes des utilisateurs. Amélioration possible : remettre bdd1 en service comme réplique
(§ 5.3) supprime le détour par l'hôte éteint.

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
| Base de données | — | (OUEDRAOGO) |

## 4. Reproductibilité et qualité (PORGO)

- **R1, reconstruction.** Sur un clone neuf, `vagrant up` suffit : le `.env` absent est créé à partir de
  `.env.exemple` avec des mots de passe aléatoires (`SecureRandom`), la box est épinglée
  (`bento/ubuntu-24.04` `202510.26.0`), et tout le reste est installé par les scripts. Premier `vagrant up`
  complet mesuré : **1 433 s** (téléchargement de la box inclus).
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

### 5.3 Remise en service de bdd1 comme nouvelle réplique (OUEDRAOGO)

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
- Toutes les VM partagent un seul processeur physique : limite des mesures de charge.
- Bascule de la base manuelle (pas de Patroni), réplication asynchrone.
- …

## 8. Annexes
- Arborescence du dépôt, extraits de configuration engendrée (`haproxy.cfg`, `keepalived.conf`).
