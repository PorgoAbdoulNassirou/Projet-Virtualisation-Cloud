#!/usr/bin/env bash
# =============================================================================
# Remise en service d'une base après une bascule (§ 5.3 du dossier)
# Rejoué à chaque « vagrant up » de bdd1 et bdd2 (run: always) ; sans effet
# en temps normal.
#
# Cas traité : bdd1 était primaire, elle est tombée, bdd2 a été promue par
# bascule_bdd.sh. Au redémarrage, PostgreSQL relance bdd1 en PRIMAIRE : deux
# primaires (cerveau divisé), et les applications, qui essaient bdd1 en
# premier, liraient l'ancienne base. Ce script la reconvertit en réplique de
# bdd2, sans geste manuel :
#   vagrant up bdd1
# (ou, sur une machine déjà allumée : vagrant provision bdd1 --provision-with reintegrer)
#
# Détection : la ligne de temps (timeline) de PostgreSQL augmente de 1 à
# chaque promotion. Si l'autre base est sur une ligne de temps PLUS RÉCENTE
# que la mienne, elle a été promue après ma chute : je suis l'ancien primaire.
# Le script est symétrique : il sert aussi si c'est bdd2 qui tombe ensuite.
# =============================================================================
set -euo pipefail
source /vagrant/scripts/lib.sh

: "${PG_MDP_REPLICATION:?PG_MDP_REPLICATION doit être fourni par Vagrant}"
moi=$(hostname -s)
case "$moi" in
  bdd1) autre=bdd2 ;;
  bdd2) autre=bdd1 ;;
  *) journal "ÉCHEC : script réservé à bdd1 et bdd2"; exit 1 ;;
esac
ip_autre=$(plateforme ip "$autre")
donnees=/var/lib/postgresql/16/main
bin=/usr/lib/postgresql/16/bin

if [ -f "$donnees/standby.signal" ]; then
  journal "réplique de ${autre} : rien à réintégrer"
  exit 0
fi
# L'autre base absente (création initiale, ou panne) : rien à comparer, on ne touche à rien.
if ! timeout 2 bash -c "exec 3<>/dev/tcp/${ip_autre}/5432" 2>/dev/null; then
  journal "${autre} injoignable : rien à réintégrer"
  exit 0
fi

ma_ligne=$(sudo -u postgres "$bin/pg_controldata" "$donnees" \
  | awk -F: '/Latest checkpoint.s TimeLineID/ {gsub(/ /, "", $2); print $2}')
# IDENTIFY_SYSTEM (connexion de réplication) renvoie : identifiant|ligne de temps|position|base
sa_ligne=$(PGPASSWORD="$PG_MDP_REPLICATION" psql \
  "host=${ip_autre} user=replicateur replication=true connect_timeout=3" \
  -tAc "IDENTIFY_SYSTEM" | cut -d'|' -f2)

if [ -z "$ma_ligne" ] || [ -z "$sa_ligne" ] || [ "$sa_ligne" -le "$ma_ligne" ]; then
  journal "primaire à jour (ligne de temps ${ma_ligne:-?}, ${autre} : ${sa_ligne:-?}) : rien à réintégrer"
  exit 0
fi

debut=$SECONDS
journal "ANCIEN PRIMAIRE détecté (ligne de temps ${ma_ligne} < ${sa_ligne} sur ${autre}) : conversion en réplique"
systemctl stop postgresql
find "$donnees" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
install -o postgres -g postgres -m 700 -d "$donnees"
PGPASSWORD="$PG_MDP_REPLICATION" sudo -u postgres --preserve-env=PGPASSWORD \
  pg_basebackup -h "$ip_autre" -p 5432 -U replicateur -D "$donnees" -R -X stream
systemctl start postgresql
attendre_port 127.0.0.1 5432 60

flux=""
for _ in $(seq 1 30); do
  flux=$(sudo -u postgres psql -tAc "SELECT status FROM pg_stat_wal_receiver" 2>/dev/null || true)
  [ "$flux" = "streaming" ] && break
  sleep 1
done
journal "réplique de ${autre} : réception du flux « ${flux:-absent} », en $(( SECONDS - debut )) s"
[ "$flux" = "streaming" ] || { journal "ÉCHEC : la réplication ne démarre pas"; exit 1; }
