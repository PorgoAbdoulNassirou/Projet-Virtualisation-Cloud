#!/usr/bin/env bash
set -euo pipefail
source /vagrant/scripts/lib.sh

primaire=$(plateforme ip bdd1)
debut_epoch=$(date +%s)
debut=$(date --iso-8601=seconds)
journal "début de bascule : $debut"

# Ne jamais promouvoir si l'ancien primaire accepte encore des connexions : cela
# évite de créer deux nœuds inscriptibles lors d'un simple incident réseau local.
if timeout 2 bash -c "exec 3<>/dev/tcp/${primaire}/5432" 2>/dev/null; then
  journal "ÉCHEC : bdd1 ($primaire:5432) est encore joignable, promotion annulée"
  exit 1
fi

if [ "$(sudo -u postgres psql -P pager=off -tAc 'SELECT pg_is_in_recovery()')" = "t" ]; then
  sudo -u postgres psql -P pager=off -v ON_ERROR_STOP=1 -c "SELECT pg_promote(true, 60)"
fi

delai=${1:-120}
debut_attente=$SECONDS
until [ "$(sudo -u postgres psql -P pager=off -tAc 'SELECT pg_is_in_recovery()' 2>/dev/null || true)" = "f" ]; do
  if (( SECONDS - debut_attente >= delai )); then
    journal "ÉCHEC : bdd2 n'est pas devenue primaire après ${delai} s"
    exit 1
  fi
  sleep 1
done

fin_epoch=$(date +%s)
fin=$(date --iso-8601=seconds)
journal "fin de bascule : $fin"
journal "durée : $((fin_epoch - debut_epoch)) s"
