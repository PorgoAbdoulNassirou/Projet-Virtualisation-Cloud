# Démonstration (livrable L4) : fiche pour le jour J

20 minutes, sur une machine vierge : destruction puis reconstruction en direct, puis **3 scénarios tirés au
sort** par l'enseignant. **L'enseignant choisit qui répond** : chacun doit savoir lancer et expliquer chaque
scénario, pas seulement le sien.

Toutes les commandes se lancent dans **Git Bash**, à la racine du dépôt.

---

## 1. Avant la séance (la veille)

| À faire | Pourquoi |
|---|---|
| Poste **Intel/AMD** (Windows ou Linux), 16 Go de RAM conseillés : celui de PORGO est validé | La box est amd64 : un Mac ARM ne la fait pas tourner |
| `git pull` puis `vagrant up` une fois, en entier | Met en cache la box (≈ 1 Go) et le paquet Grafana (≈ 380 Mo, dans `.cache/`) : la démo ne dépend presque plus d'Internet (seuls les paquets Ubuntu restent téléchargés) |
| `.env` : `NB_APP=2`, `E1_LB2=1`, `E2_OBS=1` | Les deux extensions doivent être démontrées |
| Fermer Docker Desktop, le navigateur lourd, les autres applications | 7 VM ≈ 4,4 Go de RAM ; une VM peut se figer si la mémoire manque |
| Vérifier que le port **8080** de l'hôte est libre : `netstat -ano \| findstr :8080` (PowerShell) | Un conteneur Docker ou WSL qui l'occupe fait échouer `vagrant up` sur lb1 (vécu le 25/10). Sinon : `PORT_HOTE=8081` dans `.env` |
| Ouvrir à l'avance dans le navigateur : `http://192.168.59.11:8404/stats` et `http://192.168.59.41:3000` | Statistiques HAProxy ; Grafana (utilisateur `admin`, mot de passe `GRAFANA_MDP` du `.env`) |

> ⏱ La reconstruction complète dure **≈ 30 min** (mesurée : 1 778 s à 1 934 s). Elle ne tient pas dans les
> 20 minutes : **la lancer dès l'arrivée**, avant le tour du groupe, ou demander à l'enseignant l'ordre souhaité.

---

## 2. Reconstruction en direct (R1 / V5)

```bash
bash tests/v5_reconstruction.sh        # destroy -f puis up, durée de chaque phase, vérification finale
```

À montrer pendant ce temps : le `Vagrantfile` (table `NOEUDS` = source unique de vérité, R3), `.env.exemple`
(aucun secret versionné, R7), le seul `forwarded_port` sur lb1 (R8).

---

## 3. Scénarios (attendu, puis remise en état)

| Scénario | Commande | Ce qu'on doit voir | Remise en état après |
|---|---|---|---|
| **V1** répartition | `bash tests/v1_repartition.sh` | app1 et app2 à tour de rôle, écart 0 % (< 20 %) | rien |
| **V2** panne d'une application | `bash tests/v2_panne_app.sh` | 0 requête perdue ; Grafana : app1 passe DOWN | `vagrant up app1` |
| **V3** montée en charge | `bash tests/v3_montee_charge.sh`, puis `NB_APP=4` dans `.env`, `vagrant up`, relancer | débit utile N=2 puis N=4 ; **expliquer** pourquoi il n'augmente pas (CPU partagé, bdd1 saturée, § 6.3) | `vagrant destroy -f app3 app4`, `NB_APP=2` dans `.env`, `vagrant up` |
| **V4** panne de la base | `bash tests/v4_panne_bdd.sh` | 503 **JSON** pendant la panne, bascule ≈ 3 s, retour à 200, puis bdd1 redevenue réplique | la plateforme reste saine (bdd2 primaire, bdd1 réplique) ; pour rejouer V4 dans le sens initial : `vagrant destroy -f bdd1 bdd2 && vagrant up bdd1 bdd2` (≈ 10 min) |
| **V5** reconstruction | voir § 2 | plateforme fonctionnelle sans aucune commande | rien |
| **V6** panne du répartiteur | `bash tests/v6_panne_lb.sh` | service toujours joignable sur `http://192.168.59.5`, ≈ 1 requête perdue, interruption ≈ 1,7 s | `vagrant up lb1` (il reprend l'IP virtuelle 10 s après) |

Vérifications rapides des exigences, si on les demande :

```bash
bash tests/verifier_repartition.sh r8     # seul lb1 expose un port
bash tests/verifier_repartition.sh r3     # serveurs connus de HAProxy = NB_APP
bash tests/verifier_repartition.sh r4     # serveur défaillant écarté en < 5 s
vagrant provision lb1                     # R2 : « HAProxy inchangé », « keepalived inchangé »
curl -s "http://192.168.59.5/resultat?matricule=BF000123"; echo
```

---

## 4. Questions probables (et où est la réponse)

| Question | Réponse courte | Dossier |
|---|---|---|
| Pourquoi la configuration HAProxy n'est-elle jamais écrite à la main ? | Elle est engendrée depuis la même table que le Vagrantfile : `NB_APP=4` suffit | § 2.3 |
| Comment un serveur en panne est-il écarté en moins de 5 s ? | Sonde `/sante` chaque seconde, 2 échecs, connexion bornée à 1 s | § 3.1 |
| Pourquoi `timeout check 3s` et pas 1 s ? | Sinon la sonde rejetait des serveurs sains après une bascule (bug trouvé au test) | § 3.1 |
| Comment l'application suit-elle la bascule sans redémarrer ? | `host=bdd1,bdd2 target_session_attrs=read-write` | § 3.2 |
| Que se passe-t-il quand bdd1 revient après la bascule ? | Elle se reconvertit seule en réplique (lignes de temps PostgreSQL) | § 5.3 |
| Pourquoi le débit n'augmente-t-il pas avec N = 4 ? | Un seul processeur partagé et une base saturée par une connexion par requête : c'est un résultat, pas un échec | § 6.3, § 7 |
| Où sont les mots de passe ? | Dans `.env`, créé automatiquement, jamais versionné ; fichiers en mode 600 dans les VM | § 4 |
| Qu'est-ce qui reste un point de défaillance ? | Bascule de la base manuelle, hôte physique unique | § 3.6, § 7 |
