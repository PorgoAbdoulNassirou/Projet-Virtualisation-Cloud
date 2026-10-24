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
| 23/10 | KOBENDE | Une connexion à la base par requête, sans pool | Application strictement sans état et reconnexion automatique après la bascule ; coût d'ouverture acceptable à notre échelle |
| 23/10 | KOBENDE | `target_session_attrs=read-write` sur `host=bdd1,bdd2` | L'application suit la bascule de la base sans modification ni redémarrage |
| 23/10 | KOBENDE | Service systemd sous un utilisateur système dédié, `app.env` en mode 600 | Le service ne tourne jamais en root ; le mot de passe n'est lisible que par root |
| 23/10 | KOBENDE | `connect_timeout=2` et `statement_timeout=2000` | `/sante` répond toujours avant le délai de la sonde HAProxy, même base morte |
| 24/10 | THIOMBIANO | Cibles Prometheus engendrées depuis `plateforme.json`, et rôle obs rejoué à chaque `vagrant up` comme le répartiteur | R3 : avec `NB_APP=4`, app3 et app4 apparaissent seules dans la supervision (mesuré : 7 → 9 → 7 machines) |
| 24/10 | THIOMBIANO | Tableau de bord Grafana provisionné par fichiers (`config/grafana/`) | R1 : il survit à `vagrant destroy`, c'est du code versionné, pas des clics |
| 24/10 | THIOMBIANO | node_exporter ajouté à l'appel apt unique de `commun.sh` (rotation) | Règle « un seul appel apt par script » ; lu dans `plateforme.json` comme dans `lb.sh` |
| 24/10 | THIOMBIANO | V3 : 3 tirs par valeur de N, médiane, et calcul du **débit utile** (réponses 200/s) | Un seul tir est trop bruité sur un poste partagé ; `ab` compte les 503 dans ses req/s, ce qui gonflait le chiffre |
| 24/10 | THIOMBIANO | Ne pas modifier l'application (pool de connexions) à deux jours du rendu | Décision qui revient à KOBENDE et PORGO ; il aurait fallu refaire V2, V4, R4 et V6. Goulot documenté au § 6.3 et au § 7 |

## Difficultés rencontrées et solutions

| Date | Auteur | Difficulté | Comment elle a été levée |
|---|---|---|---|
| 23/10 | PORGO | Premier `vagrant up` : la version `202404.23.0` de `bento/ubuntu-24.04` donnée dans le squelette de l'énoncé n'est pas publiée pour virtualbox/amd64 (« no available version that matches the constraints ») | Épinglage sur `202510.26.0`, la plus récente des versions publiées (202510.26.0, 202508.03.0, 202502.21.0, 202404.26.0), identique pour tout le groupe |
| 23/10 | PORGO | L'exportateur Prometheus de HAProxy n'était activé que sur lb2 : `haproxy -vv \| grep -q` échoue de façon **aléatoire** sous `set -o pipefail` (grep ferme le tube, haproxy reçoit SIGPIPE) | Sortie de `haproxy -vv` capturée dans une variable, puis test `+PROMEX` ; vérifié sur lb1 et lb2 (406 métriques) |
| 23/10 | PORGO | L'interface privée s'appelle `eth1` sur la box bento, et non `enp0s8` comme supposé dans les exemples | Rien à corriger : l'interface est détectée à partir de l'IP, jamais écrite en dur |
| 23/10 | PORGO | V6 : le 1er script calculait la « reprise » depuis le lancement de `vagrant halt` (11,9 s), alors que lb1 sert encore pendant son arrêt propre : chiffre faux | Mesure de l'interruption réelle (dernier 200 avant la panne → premier 200 après) : 1,68 s puis 1,73 s. Les deux fichiers bruts sont conservés |
| 23/10 | PORGO | R2 : bdd1 a cessé de répondre en SSH (« timeout during server version negotiating ») avec 1,8 Go de RAM libre sur l'hôte | `vagrant reload bdd1`, puis R2 rejoué : 6/6 identiques. Leçon : pendant le développement, `E2_OBS=0` et ne pas lancer d'autres applications lourdes |
| 23/10 | PORGO | Sous Git Bash, `vagrant upload fichier /tmp/x` envoyait vers un chemin Windows (conversion automatique des chemins par MSYS) | Préfixer par `MSYS_NO_PATHCONV=1` (ajouté au dépannage du README) |
| 23/10 | PORGO | Test d'intégration de la bascule (base + application + répartiteur, première fois ensemble) : après `bascule_bdd.sh` réussie (3 s), le service restait en **503**. HAProxy marquait app1/app2 `L7TOUT` : `/sante` mettait 0,6 à 2,1 s (libpq essaie bdd1 éteinte avant bdd2), au-delà de `timeout check 1s` | `timeout check` porté à 3 s (la connexion de la sonde reste bornée à 1 s, R4 inchangée sur panne franche) ; 503 de HAProxy renvoyé en JSON. Service rétabli dès le rechargement. Compromis documenté au § 3.1 du dossier |
| 23/10 | PORGO | Remise en service de bdd1 après bascule : PostgreSQL y redémarre **en primaire** (deux primaires, applications sur l'ancienne base) ; et `vagrant provision bdd2` après bascule **effaçait** bdd2 promue | `reintegrer_bdd.sh` (rejoué à chaque `vagrant up`) compare les lignes de temps et reconvertit l'ancien primaire en réplique (39 s) ; garde-fous dans `bdd.sh` et `replique.sh` ; bascule symétrique. Fenêtre résiduelle de 42,7 s mesurée et documentée (§ 5.3) |
| 23/10 | KOBENDE | Poste de développement Mac M2 (processeur ARM) : la box `bento/ubuntu-24.04` amd64 ne tourne pas sous VirtualBox, impossible de faire `vagrant up` localement | `app.py` testé sur l'hôte sans base (codes 200, 400, 404, 503 vérifiés) ; tests en VM (provision ×2, `/info`, `/sante`, V2) confiés au poste Windows de PORGO lors de la relecture de la PR |
| 24/10 | THIOMBIANO | Premier déploiement de obs : Grafana 13 met **10 min** à démarrer, le provisionnement échoue (port 3000 injoignable après 120 s) ; le noyau tue des services système | Journal de Grafana : une douzaine de plugins de sources de données chargés, chacun un processus, sur 768 Mo. `GF_PLUGINS_DISABLE_PLUGINS` (on ne garde que Prometheus) et `GF_PLUGINS_PREINSTALL_DISABLED` : provisionnement en 1 min 08 s, puis « inchangé » au rejeu |
| 24/10 | THIOMBIANO | Grafana : les machines détruites (app3, app4) restaient affichées « DOWN » après le retour à N=2, ce qui faisait croire à une panne | Panneaux d'état en requête instantanée (seules les machines existantes) et ajout d'une frise d'historique de disponibilité, qui montre au contraire les vraies pannes (V2, V4) |
| 24/10 | THIOMBIANO | V3 : 41 % (N=2) puis 53 % (N=4) de 503 sous `ab -c 50`, et le débit utile baisse quand N double | Diagnostic : bdd1 (1 vCPU) à 100 %, une connexion SCRAM par requête, attentes > `connect_timeout` ; aucune erreur côté PostgreSQL. Résultat conservé et expliqué (§ 6.3), amélioration proposée (PgBouncer) |