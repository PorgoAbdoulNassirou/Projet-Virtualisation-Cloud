#!/usr/bin/env bash
# =============================================================================
# Scénario V4 — panne de la base primaire, bascule chronométrée, remise en service
# Auteur : THIOMBIANO Yempabou Romaric Johan (ingénieur essais et observabilité)
#
# À lancer DEPUIS L'HÔTE (Git Bash), à la racine du dépôt, en situation nominale
# (bdd1 primaire, bdd2 réplique) :
#   bash tests/v4_panne_bdd.sh
#
# 1. vagrant halt bdd1, pendant qu'une sonde interroge /sante toutes les 500 ms ;
# 2. vérifie que le service répond un 503 JSON propre (jamais une page blanche ni
#    une erreur de connexion brute) ;
# 3. lance la bascule (scripts/bascule_bdd.sh sur bdd2) et la chronomètre ;
# 4. mesure le retour à 200 et la durée totale de l'interruption ;
# 5. vagrant up bdd1 : vérifie qu'elle est redevenue réplique (reintegrer_bdd.sh).
# Résultat brut enregistré dans tests/resultats/.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

VIP=$(sed -n 's/.*"vip": *"\([^"]*\)".*/\1/p' config/plateforme.json)
URL="http://${VIP}/sante"
SORTIE="tests/resultats/v4_$(date +%Y%m%d_%H%M%S).log"
SONDE="${SORTIE%.log}_sonde.log"
mkdir -p tests/resultats
exec > >(tee -a "$SORTIE") 2>&1

ms()    { date +%s%3N; }
appel() { curl -s --max-time 5 -w ' [%{http_code}]' "$1"; }
en_recuperation() {   # t = réplique, f = primaire
  vagrant ssh "$1" -c "sudo -u postgres psql -tAc 'SELECT pg_is_in_recovery()'" 2>/dev/null | tr -d '\r '
}

echo "V4 — $(date '+%d/%m/%Y %H:%M:%S') — sonde ${URL} toutes les 500 ms"
R1=$(en_recuperation bdd1); R2=$(en_recuperation bdd2)
echo "Avant : bdd1 pg_is_in_recovery = ${R1}, bdd2 = ${R2} (attendu : f / t)"
if [ "$R1" != "f" ] || [ "$R2" != "t" ]; then
  echo "Situation non nominale (bascule déjà faite ?) : reconstruire avec vagrant destroy -f bdd1 bdd2 && vagrant up"
  exit 1
fi
echo "Avant : /sante → $(appel "$URL")"

# Sonde continue, dans un fichier à part : horodatage (ms) et code HTTP.
: > "$SONDE"
( while [ ! -f "${SONDE}.fin" ]; do
    echo "$(ms) $(curl -s -o /dev/null --max-time 3 -w '%{http_code}' "$URL")" >> "$SONDE"
    sleep 0.5
  done ) &
PID_SONDE=$!
sleep 3

T_HALT=$(ms); echo "${T_HALT} vagrant halt bdd1"
vagrant halt bdd1 >/dev/null 2>&1
T_ARRET=$(ms); echo "${T_ARRET} bdd1 arrêtée ($(( (T_ARRET - T_HALT) / 1000 )) s d'arrêt propre)"
sleep 3
echo "Pendant la panne, via l'IP virtuelle :"
echo "  /sante    → $(appel "$URL")"
echo "  /resultat → $(appel "http://${VIP}/resultat?matricule=BF000123")"

T_BASCULE=$(ms); echo "${T_BASCULE} lancement de bascule_bdd.sh sur bdd2"
vagrant ssh bdd2 -c "sudo bash /vagrant/scripts/bascule_bdd.sh" 2>&1 | tr -d '\r' | grep '=='
T_FIN_BASCULE=$(ms)
echo "${T_FIN_BASCULE} fin de la commande de bascule ($(( (T_FIN_BASCULE - T_BASCULE) / 1000 )) s, session vagrant ssh comprise)"

until [ "$(curl -s -o /dev/null --max-time 3 -w '%{http_code}' "$URL")" = "200" ]; do
  if (( $(ms) - T_FIN_BASCULE > 60000 )); then echo "Service NON rétabli 60 s après la bascule"; break; fi
  sleep 0.2
done
T_OK=$(ms)
echo "${T_OK} /sante = 200 : service rétabli $(( T_OK - T_FIN_BASCULE )) ms après la fin de la bascule"
echo "Après : /resultat → $(appel "http://${VIP}/resultat?matricule=BF000123")"
sleep 3
touch "${SONDE}.fin"; wait "$PID_SONDE"; rm -f "${SONDE}.fin"

echo
echo "===== Analyse de la sonde (${SONDE}) ====="
awk '
  NF == 2 {
    total++; codes[$2]++
    if ($2 != "200") { if (!debut) debut = $1; fin_panne = 0 }
    else if (debut && !fin_panne) fin_panne = $1
  }
  END {
    printf "Sondes : %d — ", total
    for (c in codes) printf "%s : %d  ", (c == "000" ? "erreur de connexion" : c), codes[c]
    printf "\n"
    if (debut && fin_panne)
      printf "Interruption vue des utilisateurs (1er non-200 → retour à 200) : %.1f s\n", (fin_panne - debut) / 1000
    printf "Réponses brutes sans code HTTP (page blanche, connexion refusée) : %d\n", codes["000"] + 0
  }' "$SONDE"

echo
echo "===== Remise en service de bdd1 (vagrant up bdd1) ====="
T_UP=$(ms)
vagrant up bdd1 2>&1 | tr -d '\r' | grep -E '== \[bdd1\]'
T_UP_FIN=$(ms)
echo "vagrant up bdd1 : $(( (T_UP_FIN - T_UP) / 1000 )) s (démarrage de la VM compris)"
echo "Après : bdd1 pg_is_in_recovery = $(en_recuperation bdd1), bdd2 = $(en_recuperation bdd2) (attendu : t / f)"
echo "Après : /sante → $(appel "$URL")"
echo "Résultat brut : ${SORTIE} et ${SONDE}"
