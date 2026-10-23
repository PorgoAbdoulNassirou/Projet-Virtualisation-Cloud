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

# Analyse. « vagrant halt » arrête lb1 proprement en une dizaine de secondes,
# pendant lesquelles lb1 sert encore : on mesure donc l'interruption RÉELLE,
# du dernier succès avant la 1re erreur au 1er succès après la dernière erreur.
awk '
  NF == 2 && $2 ~ /^[0-9]+$/ {
    total++
    if ($2 == "200") {
      if (!echecs) dernier_ok = $1          # dernier succès avant la panne
      else if (!reprise) reprise = $1       # premier succès après une erreur
    } else {
      echecs++; reprise = 0                 # une nouvelle erreur annule la reprise
    }
  }
  END {
    printf "Requêtes envoyées       : %d\n", total
    printf "Requêtes en échec       : %d\n", echecs
    if (echecs && reprise)
      printf "Interruption réelle     : %.2f s (dernier 200 avant panne → premier 200 après)\n", (reprise - dernier_ok) / 1000
    else if (echecs)
      print "Service NON rétabli pendant l observation"
    else
      print "Aucune requête perdue."
  }' "$SORTIE" | tee -a "$SORTIE"

echo "Résultat brut : ${SORTIE}"
echo "Pensez à relancer lb1 : vagrant up lb1"
