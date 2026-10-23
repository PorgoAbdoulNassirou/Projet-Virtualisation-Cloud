#!/usr/bin/env bash
set -euo pipefail
source /vagrant/scripts/lib.sh

: "${PG_MDP_REPLICATION:?PG_MDP_REPLICATION doit être fourni par Vagrant}"
primaire=$(plateforme ip bdd1)
reseau=$(plateforme valeur reseau)

journal "installation de PostgreSQL et préparation de la réplique"
installer_paquets postgresql-16

tmp=$(mktemp)
printf "listen_addresses = '*'\nport = 5432\npassword_encryption = 'scram-sha-256'\n" > "$tmp"
if installer_si_change "$tmp" /etc/postgresql/16/main/conf.d/resultats-bf.conf 644; then
  systemctl restart postgresql
fi

tmp=$(mktemp)
cat > "$tmp" <<EOF
# Connexions locales d'administration
local   all             postgres                                peer
local   all             all                                     peer
# Accès applicatif depuis le réseau privé du projet
host    resultats       app_resultats   ${reseau}   scram-sha-256
# Réplication physique depuis bdd2
host    replication     replicateur     ${reseau}   scram-sha-256
EOF
installer_si_change "$tmp" /etc/postgresql/16/main/pg_hba.conf 644 || [ "$?" -eq 1 ]
# Le fichier est généré par root ; il doit rester lisible par PostgreSQL.
chmod 644 /etc/postgresql/16/main/pg_hba.conf

replica=/var/lib/postgresql/16/main
# Garde-fou : après une bascule, bdd2 est PRIMAIRE (plus de standby.signal) et
# contient la base « resultats ». Sans ce test, rejouer ce script l'effacerait
# pour la recopier depuis l'ancien primaire. Une installation neuve, elle, n'a
# pas encore la base « resultats ».
promue=0
if [ ! -f "$replica/standby.signal" ] && \
   [ "$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname = 'resultats'" 2>/dev/null)" = "1" ]; then
  promue=1
  journal "bdd2 a été promue primaire (bascule) : aucune réinitialisation"
fi

if [ ! -f "$replica/standby.signal" ] && [ "$promue" -eq 0 ]; then
  attendre_port "$primaire" 5432 120
  systemctl stop postgresql
  find "$replica" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  install -o postgres -g postgres -m 700 -d "$replica"
  export PGPASSWORD="$PG_MDP_REPLICATION"
  sudo -u postgres --preserve-env=PGPASSWORD pg_basebackup \
    -h "$primaire" -p 5432 -U replicateur -D "$replica" -R -X stream -v
  unset PGPASSWORD
  chown -R postgres:postgres "$replica"
  chmod 700 "$replica"
fi

systemctl enable postgresql
systemctl start postgresql
attendre_port 127.0.0.1 5432 120
systemctl reload postgresql
sudo -u postgres psql -v ON_ERROR_STOP=1 -Atc "SELECT pg_reload_conf()" >/dev/null
regle=$(sudo -u postgres psql -v ON_ERROR_STOP=1 -tAc "SELECT count(*) FROM pg_hba_file_rules WHERE 'replication'=ANY(database) AND 'replicateur'=ANY(user_name) AND address='${reseau%/*}' AND netmask='255.255.255.0' AND error IS NULL")
if [ "$regle" -lt 1 ]; then
  journal "ÉCHEC : règle pg_hba de réplication absente ou invalide"
  exit 1
fi
journal "bdd2 prête, pg_is_in_recovery = $(sudo -u postgres psql -tAc 'SELECT pg_is_in_recovery()') (t = réplique, f = primaire après bascule)"
