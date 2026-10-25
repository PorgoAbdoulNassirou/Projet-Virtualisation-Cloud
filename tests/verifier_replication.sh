#!/usr/bin/env bash
# Vérification R5 : une écriture sur bdd1 est rejouée sur bdd2.
set -euo pipefail

RACINE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$RACINE"

for machine in bdd1 bdd2; do
  etat=$(vagrant ssh "$machine" -c \
    "sudo -u postgres psql -P pager=off -v ON_ERROR_STOP=1 -d resultats -Atc 'SELECT pg_is_in_recovery()'" \
    | tr -d '\r')
  if [[ "$machine" == bdd1 && "$etat" != f ]]; then
    echo "ÉCHEC : bdd1 n'est pas le primaire (pg_is_in_recovery=$etat)" >&2
    exit 1
  fi
  if [[ "$machine" == bdd2 && "$etat" != t ]]; then
    echo "ÉCHEC : bdd2 n'est pas en récupération (pg_is_in_recovery=$etat)" >&2
    exit 1
  fi
done

matricule="R5TEST$(date +%s)${RANDOM}"
insere=0
nettoyer() {
  if (( insere )); then
    vagrant ssh bdd1 -c \
      "sudo -u postgres psql -P pager=off -v ON_ERROR_STOP=1 -d resultats -c \"DELETE FROM resultats WHERE matricule='$matricule'\"" \
      >/dev/null 2>&1 || true
  fi
}
trap nettoyer EXIT

echo "Commande bdd1 : INSERT d'une ligne temporaire (${matricule})"
vagrant ssh bdd1 -c \
  "sudo -u postgres psql -P pager=off -v ON_ERROR_STOP=1 -d resultats -c \"INSERT INTO resultats (matricule, nom, serie, moyenne, admis) VALUES ('$matricule', 'Test R5', 'A', 12.50, true)\""
insere=1

delai=${DELAI_REPLICATION:-30}
for ((seconde = 1; seconde <= delai; seconde++)); do
  ligne=$(vagrant ssh bdd2 -c \
    "sudo -u postgres psql -P pager=off -v ON_ERROR_STOP=1 -d resultats -AtF '|' -c \"SELECT matricule, nom, serie, moyenne, admis FROM resultats WHERE matricule='$matricule'\"" \
    | tr -d '\r')
  if [[ "$ligne" == "$matricule|Test R5|A|12.50|t" ]]; then
    echo "Commande bdd2 : SELECT de la ligne (${matricule})"
    echo "Résultat : $ligne"
    echo "R5 VALIDÉ : écriture primaire visible sur la réplique après ${seconde} s."
    exit 0
  fi
  sleep 1
done

echo "ÉCHEC R5 : ligne absente de bdd2 après ${delai} s" >&2
exit 1
