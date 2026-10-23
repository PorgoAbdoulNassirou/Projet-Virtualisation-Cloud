#!/usr/bin/env bash
# =============================================================================
# Scénario V6 — panne du répartiteur actif (extension E1)
# Auteur : PORGO Abdoul Nassirou (commit hors domaine, rotation obligatoire)
#
# À lancer DEPUIS L'HÔTE (Git Bash), à la racine du dépôt :
#   bash tests/v6_panne_lb.sh
#
# Interroge l'IP virtuelle toutes les 200 ms, éteint lb1 au bout de 5 s, puis
# mesure le nombre de requêtes en échec et la durée de la période dégradée.
# Résultat brut enregistré dans tests/resultats/.
# Remettre lb1 en service ensuite : vagrant up lb1
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

VIP=$(sed -n 's/.*"vip": *"\([^"]*\)".*/\1/p' config/plateforme.json)
URL="http://${VIP}/info"
DUREE=${DUREE:-40}                       # secondes d'observation
SORTIE="tests/resultats/v6_$(date +%Y%m%d_%H%M%S).log"
mkdir -p tests/resultats

echo "V6 — cible ${URL}, observation ${DUREE} s, lb1 éteint à t = 5 s" | tee "$SORTIE"
( sleep 5; echo "$(date +%s%3N) ARRET_LB1" >> "$SORTIE"; vagrant halt lb1 >/dev/null 2>&1 ) &

FIN=$(( $(date +%s) + DUREE ))
while [ "$(date +%s)" -lt "$FIN" ]; do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 1 "$URL")
  echo "$(date +%s%3N) ${CODE}" >> "$SORTIE"
  sleep 0.2
done
wait

# Analyse : requêtes totales, échecs, première et dernière erreur.
awk '
  $2 == "ARRET_LB1" { arret = $1; next }
  NF == 2 && $2 ~ /^[0-9]+$/ {
    total++
    if ($2 != "200") { echecs++; if (!debut) debut = $1; fin = $1 }
  }
  END {
    printf "Requêtes envoyées      : %d\n", total
    printf "Requêtes en échec      : %d\n", echecs
    if (echecs) {
      printf "Période dégradée       : %.1f s (de la 1re à la dernière erreur)\n", (fin - debut) / 1000
      if (arret) printf "Reprise après l arrêt  : %.1f s\n", (fin - arret) / 1000
    } else {
      print "Aucune requête perdue."
    }
  }' "$SORTIE" | tee -a "$SORTIE"

echo "Résultat brut : ${SORTIE}"
echo "Pensez à relancer lb1 : vagrant up lb1"
