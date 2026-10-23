#!/usr/bin/env bash
# =============================================================================
# Rôle « app » (app1 … appN) — service HTTP sans état
# Responsable : KOBENDE Pêgdwendé Evrard (ingénieur applicatif)
#
# CONTRAT (voir docs/PLAN_DE_TRAVAIL.md) :
#   - paquets groupés : installer_paquets python3-psycopg2
#   - copier /vagrant/app/app.py vers /opt/resultats-bf/app.py (pas d'exécution
#     depuis le dossier synchronisé)
#   - fichier /etc/resultats-bf/app.env (mode 600, jamais dans le dépôt) :
#       PG_HOTES=<ip bdd1>,<ip bdd2>   ← lus avec « plateforme ip bdd1 / bdd2 »
#       PG_BASE=resultats  PG_UTIL=app_resultats  PG_MDP=$PG_MDP_APP
#   - service systemd « resultats-app » : Restart=always, utilisateur non root,
#     EnvironmentFile=/etc/resultats-bf/app.env
#   - écoute sur 0.0.0.0:3000 (piège n° 1 : jamais 127.0.0.1)
#   - le service démarre même si la base est absente (/sante renvoie 503)
# =============================================================================
set -euo pipefail
source /vagrant/scripts/lib.sh

journal "TODO (KOBENDE) : déployer le service applicatif"
