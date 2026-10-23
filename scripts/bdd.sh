#!/usr/bin/env bash
set -euo pipefail
source /vagrant/scripts/lib.sh

: "${PG_MDP_APP:?PG_MDP_APP doit être fourni par Vagrant}"
: "${PG_MDP_REPLICATION:?PG_MDP_REPLICATION doit être fourni par Vagrant}"
reseau=$(plateforme valeur reseau)

journal "installation de PostgreSQL primaire"
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
# installer_si_change crée le fichier en root:root ; PostgreSQL doit pouvoir le lire.
chmod 644 /etc/postgresql/16/main/pg_hba.conf
systemctl reload postgresql
sudo -u postgres psql -v ON_ERROR_STOP=1 -Atc "SELECT pg_reload_conf()" >/dev/null
regle=$(sudo -u postgres psql -v ON_ERROR_STOP=1 -tAc "SELECT count(*) FROM pg_hba_file_rules WHERE 'replication'=ANY(database) AND 'replicateur'=ANY(user_name) AND address='${reseau%/*}' AND netmask='255.255.255.0' AND error IS NULL")
if [ "$regle" -lt 1 ]; then
  journal "ÉCHEC : règle pg_hba de réplication absente ou invalide"
  exit 1
fi

attendre_port 127.0.0.1 5432 120

sudo -u postgres psql -v ON_ERROR_STOP=1 <<'SQL'
SELECT 'CREATE DATABASE resultats'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'resultats')\gexec
SQL
for spec in "app_resultats:${PG_MDP_APP}:LOGIN" "replicateur:${PG_MDP_REPLICATION}:LOGIN REPLICATION"; do
  role=${spec%%:*}; reste=${spec#*:}; mdp=${reste%%:*}; attributs=${reste#*:}
  sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$role') THEN
    EXECUTE format('ALTER ROLE %I WITH %s PASSWORD %L', '$role', '$attributs', '$mdp');
  ELSE
    EXECUTE format('CREATE ROLE %I WITH %s PASSWORD %L', '$role', '$attributs', '$mdp');
  END IF;
END
\$\$;
SQL
done

sudo -u postgres psql -d resultats -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS resultats (
  matricule text PRIMARY KEY,
  nom text,
  serie text,
  moyenne numeric(4,2),
  admis boolean
);
INSERT INTO resultats (matricule, nom, serie, moyenne, admis)
SELECT 'BF' || lpad(n::text, 6, '0'),
       'Eleve ' || lpad(n::text, 6, '0'),
       CASE WHEN n % 3 = 0 THEN 'C' WHEN n % 3 = 1 THEN 'A' ELSE 'D' END,
       ((n * 37) % 2001)::numeric / 100,
       ((n * 37) % 2001) >= 1000
FROM generate_series(1, 50000) AS n
ON CONFLICT (matricule) DO NOTHING;
GRANT CONNECT ON DATABASE resultats TO app_resultats;
GRANT USAGE ON SCHEMA public TO app_resultats;
GRANT SELECT ON TABLE resultats TO app_resultats;
SQL

journal "primaire prêt : $(sudo -u postgres psql -d resultats -tAc 'SELECT count(*) FROM resultats') lignes"
