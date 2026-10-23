#!/usr/bin/env bash
# =============================================================================
# Scénario V2 — panne d'un serveur applicatif pendant une charge continue
# Auteur : KOBENDE Pêgdwendé Evrard (commit hors domaine, rotation obligatoire)
#
# À lancer DEPUIS L'HÔTE (Git Bash), à la racine du dépôt :
#   bash tests/v2_panne_app.sh
#
# Interroge /info sur l'IP virtuelle toutes les 200 ms, éteint app1 au bout de
# 5 s, puis compte les requêtes perdues et mesure la période dégradée : une
# requête est « dégradée » si elle échoue ou si elle dépasse SEUIL_LENT secondes
# (HAProxy la rejoue alors sur app2, ce qui la ralentit sans la perdre).
# Résultat brut enregistré dans tests/resultats/.
# Remettre app1 en service ensuite : vagrant up app1
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

VIP=$(sed -n 's/.*"vip": *"\([^"]*\)".*/\1/p' config/plateforme.json)
URL="http://${VIP}/info"
DUREE=${DUREE:-40}                       # secondes d'observation
SEUIL_LENT=${SEUIL_LENT:-0.5}            # au-delà, la requête compte comme dégradée
SORTIE="tests/resultats/v2_$(date +%Y%m%d_%H%M%S).log"
mkdir -p tests/resultats

echo "V2 — cible ${URL}, observation ${DUREE} s, app1 éteint à t = 5 s, seuil lent ${SEUIL_LENT} s" | tee "$SORTIE"
( sleep 5; echo "$(date +%s%3N) ARRET_APP1" >> "$SORTIE"; vagrant halt app1 >/dev/null 2>&1 ) &

# Une ligne par requête : horodatage (ms), code HTTP, durée (s), serveur ayant répondu.
FIN=$(( $(date +%s) + DUREE ))
while [ "$(date +%s)" -lt "$FIN" ]; do
  REPONSE=$(curl -s --max-time 2 -w ' %{http_code} %{time_total}' "$URL")
  SERVEUR=$(echo "$REPONSE" | sed -n 's/.*"serveur": *"\([^"]*\)".*/\1/p')
  # Code et durée sont en fin de dernière ligne (le corps peut être une page HTML d'erreur).
  CODE_DUREE=$(echo "$REPONSE" | tail -n 1 | awk '{print $(NF-1), $NF}')
  echo "$(date +%s%3N) ${CODE_DUREE} ${SERVEUR:--}" >> "$SORTIE"
  sleep 0.2
done
wait

awk -v seuil="$SEUIL_LENT" '
  $2 == "ARRET_APP1" { arret = $1; next }
  NF == 4 && $2 ~ /^[0-9]+$/ {
    total++; par_serveur[$4]++
    if ($2 != "200") echecs++
    if ($4 == "app1") dernier_app1 = $1
    if ($2 != "200" || $3 + 0 > seuil) {
      degradees++
      if (!debut) debut = $1
      fin = $1 + $3 * 1000                  # fin de la dernière requête dégradée
    }
  }
  END {
    printf "Requêtes envoyées        : %d\n", total
    printf "Requêtes perdues (≠ 200) : %d\n", echecs
    printf "Requêtes dégradées       : %d (échec ou > %s s)\n", degradees, seuil
    for (s in par_serveur) printf "  réponses de %-11s : %d\n", s, par_serveur[s]
    if (arret && dernier_app1)
      printf "Dernière réponse d app1  : %.2f s après l ordre d arrêt\n", (dernier_app1 - arret) / 1000
    if (degradees)
      printf "Période dégradée         : %.2f s (première → fin de la dernière requête dégradée)\n", (fin - debut) / 1000
    else
      print "Aucune requête dégradée."
  }' "$SORTIE" | tee -a "$SORTIE"

echo "Résultat brut : ${SORTIE}"
echo "Pensez à relancer app1 : vagrant up app1"
