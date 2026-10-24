#!/usr/bin/env bash
# =============================================================================
# Scénario V1 — répartition : 20 appels successifs à /info
# Auteur : THIOMBIANO Yempabou Romaric Johan (ingénieur essais et observabilité)
#
# À lancer DEPUIS L'HÔTE (Git Bash), à la racine du dépôt :
#   bash tests/v1_repartition.sh            (APPELS=40 bash … pour en faire plus)
#
# Le serveur qui a répondu est lu dans l'en-tête X-Serveur posé par HAProxy.
# Écart = (plus sollicité − moins sollicité) / part attendue (APPELS / N) :
# exigence < 20 %. Les serveurs attendus viennent de config/plateforme.json,
# donc un serveur qui ne répond jamais compte pour 0 (il n'est pas oublié).
# Résultat brut enregistré dans tests/resultats/.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

VIP=$(sed -n 's/.*"vip": *"\([^"]*\)".*/\1/p' config/plateforme.json)
URL="http://${VIP}/info"
APPELS=${APPELS:-20}
SERVEURS=$(sed -n 's/.*"nom": *"\(app[0-9]*\)".*/\1/p' config/plateforme.json | tr '\n' ' ')
SORTIE="tests/resultats/v1_$(date +%Y%m%d_%H%M%S).log"
mkdir -p tests/resultats

echo "V1 — $(date '+%d/%m/%Y %H:%M:%S') — ${APPELS} appels à ${URL}, serveurs attendus : ${SERVEURS}" | tee "$SORTIE"

# Une ligne par appel : numéro, code HTTP, serveur ayant répondu.
for i in $(seq 1 "$APPELS"); do
  ENTETES=$(curl -s -D - -o /dev/null --max-time 3 -w 'CODE %{http_code}\n' "$URL" | tr -d '\r')
  CODE=$(echo "$ENTETES" | awk '/^CODE/ {print $2}')
  SERVEUR=$(echo "$ENTETES" | awk 'tolower($1) == "x-serveur:" {print $2}')
  echo "$i ${CODE} ${SERVEUR:--}" >> "$SORTIE"
done

awk -v appels="$APPELS" -v serveurs="$SERVEURS" '
  NF == 3 && $1 ~ /^[0-9]+$/ {
    if ($2 != "200") echecs++
    compte[$3]++; ordre = ordre " " $3
  }
  END {
    n = split(serveurs, liste, " ")
    attendu = appels / n
    max = -1; min = appels + 1
    printf "Ordre des réponses :%s\n", ordre
    for (i = 1; i <= n; i++) {
      c = compte[liste[i]] + 0
      printf "  %-6s : %d appel(s)\n", liste[i], c
      if (c > max) max = c
      if (c < min) min = c
    }
    printf "Appels en échec (≠ 200) : %d\n", echecs + 0
    ecart = (max - min) / attendu * 100
    printf "Écart (max − min) / part attendue (%.1f) : %.1f %% → exigence < 20 %% : %s\n", \
           attendu, ecart, (ecart < 20 ? "SATISFAITE" : "NON satisfaite")
  }' "$SORTIE" | tee -a "$SORTIE"

echo "Résultat brut : ${SORTIE}"
