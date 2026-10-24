#!/usr/bin/env bash
# =============================================================================
# Scénario V3 — montée en charge : ab -n 2000 -c 50, avec N=2 puis N=4
# Auteur : THIOMBIANO Yempabou Romaric Johan (ingénieur essais et observabilité)
#
# À lancer DEPUIS L'HÔTE (Git Bash), à la racine du dépôt, une fois par valeur de N :
#   bash tests/v3_montee_charge.sh                 (N actuel, lu dans plateforme.json)
#   puis NB_APP=4 dans .env, « vagrant up », et relancer le script.
#
# Chaque mesure est répétée REPETITIONS fois (3 par défaut) après un échauffement
# non compté : un seul tir d'ab sur un poste partagé est trop bruité pour conclure.
# On retient la médiane. -l : longueur de réponse variable acceptée (le nom du
# serveur fait partie du JSON). Résultat brut d'ab enregistré dans tests/resultats/.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

VIP=$(sed -n 's/.*"vip": *"\([^"]*\)".*/\1/p' config/plateforme.json)
PREFIXE=$(sed -n 's/.*"prefixe": *"\([^"]*\)".*/\1/p' config/plateforme.json)
N=$(grep -c '"role": "app"' config/plateforme.json)
URL="http://${VIP}/resultat?matricule=BF000123"
REQUETES=${REQUETES:-2000}
CONCURRENCE=${CONCURRENCE:-50}
REPETITIONS=${REPETITIONS:-3}
SORTIE="tests/resultats/v3_N${N}_$(date +%Y%m%d_%H%M%S).log"
mkdir -p tests/resultats
exec > >(tee -a "$SORTIE") 2>&1

command -v ab >/dev/null || { echo "ab introuvable : voir docs/INSTALLATION.md § 3"; exit 1; }

echo "V3 — $(date '+%d/%m/%Y %H:%M:%S') — N = ${N} serveur(s) applicatif(s)"
echo "Commande : ab -l -n ${REQUETES} -c ${CONCURRENCE} ${URL}  (×${REPETITIONS}, après échauffement)"
echo "Poste : $(powershell -NoProfile -Command '(Get-CimInstance Win32_Processor).Name; "{0:N1} Go de RAM" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)' 2>/dev/null | tr -d '\r' | paste -sd ',' -)"

# Les N serveurs doivent être UP dans HAProxy, sinon la mesure ne veut rien dire.
UP=$(curl -s "http://${PREFIXE}.11:8404/stats;csv" | awk -F, '$1 == "serveurs_applicatifs" && $2 ~ /^app/ && $18 ~ /^UP/' | wc -l)
echo "Serveurs UP dans HAProxy (lb1) : ${UP} / ${N}"
[ "$UP" -eq "$N" ] || echo "ATTENTION : tous les serveurs ne sont pas UP, mesure à refaire"

ab -l -n 200 -c 10 "$URL" >/dev/null 2>&1    # échauffement, non compté

RESULTATS=()
for r in $(seq 1 "$REPETITIONS"); do
  echo
  echo "===== Tir ${r} / ${REPETITIONS} — $(date '+%H:%M:%S') ====="
  BRUT=$(ab -l -n "$REQUETES" -c "$CONCURRENCE" "$URL" 2>&1 | tr -d '\r')
  echo "$BRUT" | sed -n '/^Concurrency Level/,/^Transfer rate/p;/^Percentage/,$p'
  # ab compte aussi les 503 dans « Requests per second » : on calcule en plus le
  # débit utile (réponses 200 par seconde) et la part d'erreurs.
  RESULTATS+=("$(echo "$BRUT" | awk -v total="$REQUETES" '
    /^Time taken for tests/ { duree = $5 }
    /^Requests per second/  { rps = $4 }
    /^Non-2xx responses/    { non2xx = $3 }
    END { printf "%s %.2f %.1f", rps, (total - non2xx) / duree, non2xx * 100 / total }')")
  sleep 10                                   # laisser retomber la charge entre deux tirs
done

echo
echo "===== Synthèse N = ${N} ====="
printf '%s\n' "${RESULTATS[@]}" | sort -n -k2 | awk -v n="$N" '
  { rps[NR] = $1; utile[NR] = $2; err[NR] = $3
    printf "  tir : %7.2f requêtes/s (ab), %7.2f réponses 200/s, %5.1f %% de non-2xx\n", $1, $2, $3 }
  END {
    m = (NR % 2) ? (NR + 1) / 2 : NR / 2
    printf "Médiane N = %d (tir médian en débit utile) : %.1f réponses 200/s, %.1f requêtes/s selon ab, %.1f %% de non-2xx\n", \
           n, utile[m], rps[m], err[m]
  }'
echo "Résultat brut : ${SORTIE}"
