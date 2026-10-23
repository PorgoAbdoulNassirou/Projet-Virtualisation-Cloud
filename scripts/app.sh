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

: "${PG_MDP_APP:?PG_MDP_APP doit être fourni par Vagrant}"

installer_paquets python3-psycopg2

# Utilisateur système dédié : le service ne tourne jamais en root.
id -u resultats >/dev/null 2>&1 \
  || useradd --system --no-create-home --shell /usr/sbin/nologin resultats

# Chaque fichier n'est remplacé que s'il a changé ; on retient s'il faut redémarrer.
redemarrer=0

tmp=$(mktemp)
cp /vagrant/app/app.py "$tmp"
if installer_si_change "$tmp" /opt/resultats-bf/app.py 644; then redemarrer=1; fi

# Mode 600, propriété root : seul systemd le lit, avant de passer à l'utilisateur resultats.
tmp=$(mktemp)
cat > "$tmp" <<EOF
PG_HOTES=$(plateforme ip bdd1),$(plateforme ip bdd2)
PG_BASE=resultats
PG_UTIL=app_resultats
PG_MDP=${PG_MDP_APP}
EOF
if installer_si_change "$tmp" /etc/resultats-bf/app.env 600; then redemarrer=1; fi

tmp=$(mktemp)
cat > "$tmp" <<'EOF'
[Unit]
Description=RÉSULTATS-BF : service applicatif
After=network-online.target
Wants=network-online.target

[Service]
User=resultats
Group=resultats
EnvironmentFile=/etc/resultats-bf/app.env
ExecStart=/usr/bin/python3 /opt/resultats-bf/app.py
Restart=always
RestartSec=1
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
if installer_si_change "$tmp" /etc/systemd/system/resultats-app.service 644; then
  systemctl daemon-reload
  redemarrer=1
fi

systemctl enable --quiet resultats-app
if [ "$redemarrer" -eq 1 ]; then
  systemctl restart resultats-app
  journal "service resultats-app (re)démarré"
else
  journal "service resultats-app inchangé"
fi
systemctl is-active --quiet resultats-app || systemctl start resultats-app

attendre_port "$(plateforme ip "$(hostname -s)")" 3000 30
journal "application à l'écoute sur le port 3000"
