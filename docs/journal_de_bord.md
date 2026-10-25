---
title: "Journal de bord : RÉSULTATS-BF"
author:
  - "Groupe 04 : KOBENDE Pêgdwendé Evrard, PORGO Abdoul Nassirou, OUEDRAOGO Armand Hendrix, THIOMBIANO Yempabou Romaric Johan"
date: "M1 Informatique, IBAM · Virtualisation et Cloud Computing · Dr SOMDA · 26 octobre 2026"
---

Le détail de chaque point est dans le dossier d'architecture (§ indiqué).

**Rôles.** PORGO Abdoul Nassirou : architecte réseau et répartition (E1). KOBENDE Pêgdwendé Evrard :
ingénieur applicatif. OUEDRAOGO Armand Hendrix : ingénieur données. THIOMBIANO Yempabou Romaric Johan :
ingénieur essais et observabilité (E2). Commits hors de son domaine (rotation) : V2 par KOBENDE, V6 et
remise en service de la base par PORGO, node_exporter dans `commun.sh` par THIOMBIANO.

## Décisions prises et pourquoi

| Qui | Décision | Pourquoi |
|---|---|---|
| Groupe | Extensions E1 et E2 | Les plus démontrables, indépendantes du code applicatif |
| PORGO | HAProxy plutôt que Nginx | Sonde active sur `/sante` (Nginx libre : contrôles passifs), rejeu `retry-on`, métriques intégrées |
| PORGO | HAProxy et keepalived engendrés depuis `plateforme.json` | R3 : aucune adresse en dur, même source que le Vagrantfile |
| PORGO | `.env` créé au premier `vagrant up`, mots de passe aléatoires | Concilier R1 (aucun geste manuel) et R7 (aucun secret versionné) |
| PORGO | VRRP unicast, deux LB en BACKUP, priorités 150/100 | Ne pas dépendre du multicast ; pas de double maître au démarrage |
| KOBENDE | Une connexion à la base par requête, sans pool | Application strictement sans état, reconnexion naturelle après bascule |
| KOBENDE | `host=bdd1,bdd2 target_session_attrs=read-write` | L'application suit la bascule sans modification ni redémarrage |
| KOBENDE | Service systemd non root, `app.env` en 600 ; `connect_timeout=2` | Moindre privilège ; `/sante` répond toujours avant le délai de la sonde |
| THIOMBIANO | Cibles Prometheus engendrées, rôle obs rejoué à chaque `vagrant up` | R3 : app3 et app4 apparaissent seules (mesuré : 7 → 9 → 7 machines) |
| THIOMBIANO | Tableau de bord Grafana provisionné par fichiers | R1 : il survit à `vagrant destroy` |
| THIOMBIANO | V3 : 3 tirs par N, médiane, **débit utile** (réponses 200/s) | Un tir est trop bruité ; `ab` compte les 503 dans ses req/s |
| THIOMBIANO | Ne pas ajouter de pool de connexions à deux jours du rendu | Décision de KOBENDE et PORGO ; aurait imposé de refaire V2, V4, R4, V6 |

## Difficultés rencontrées et solutions

| Qui | Difficulté | Solution |
|---|---|---|
| PORGO | La box `202404.23.0` du squelette n'existe pas pour virtualbox/amd64 | Épinglage sur `202510.26.0` pour tout le groupe |
| PORGO | Exportateur Prometheus actif sur lb2 seulement : `haproxy -vv` filtré par `grep -q` échoue au hasard sous `pipefail` (SIGPIPE) | Sortie capturée dans une variable avant le test |
| PORGO | V6 : première mesure prise depuis l'ordre `vagrant halt`, alors que lb1 sert encore pendant son arrêt | Mesure de l'interruption réelle : 1,7 s ; les deux fichiers bruts sont conservés |
| PORGO | VM figée en SSH par manque de RAM sur l'hôte | `vagrant reload` ; `E2_OBS=0` pendant le développement |
| PORGO | Après une bascule réussie, service toujours en 503 : `/sante` dépasse `timeout check 1s` (libpq essaie d'abord bdd1 éteinte) | `timeout check 3s` ; compromis documenté (§ 3.1) |
| PORGO | bdd1 rallumée après bascule redémarre en primaire (deux primaires) ; `provision bdd2` effaçait la base promue | `reintegrer_bdd.sh` compare les lignes de temps et reconvertit en réplique (§ 5.3) |
| KOBENDE | Mac M2 (ARM) : la box amd64 ne tourne pas | `app.py` testé sans base sur l'hôte ; tests en VM sur le poste de PORGO |
| THIOMBIANO | Grafana 13 met 10 min à démarrer sur 768 Mo (une douzaine de plugins, un processus chacun) : provisionnement en échec | Plugins inutiles désactivés : 1 min 08 s, puis « inchangé » au rejeu (§ 3.5) |
| THIOMBIANO | Grafana affichait DOWN des machines détruites volontairement (retour à N = 2) | États en requête instantanée, frise d'historique des pannes |
| PORGO | Validation finale (7 machines) : `vagrant up` en échec sur obs, apt.grafana.com injoignable depuis le réseau du poste (connexion réinitialisée), alors que dl.grafana.com répond | Grafana 13.2.4 installé depuis le paquet `.deb` de dl.grafana.com, empreinte SHA-256 inscrite dans `obs.sh`, mis en cache dans `.cache/` : la reconstruction ne dépend plus de ce dépôt |
| THIOMBIANO | V3 : 41 % puis 53 % de 503 sous `ab -c 50`, débit utile en baisse quand N double | Diagnostic : bdd1 (1 vCPU) saturée par une connexion SCRAM par requête ; résultat expliqué (§ 6.3), PgBouncer proposé (§ 7) |
