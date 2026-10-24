#!/usr/bin/env bash
# =============================================================================
# Scénario V5 — reconstruction intégrale : vagrant destroy -f puis vagrant up
# Auteur : THIOMBIANO Yempabou Romaric Johan (ingénieur essais et observabilité)
#
# À lancer DEPUIS L'HÔTE (Git Bash), à la racine du dépôt :
#   bash tests/v5_reconstruction.sh
#
# DÉTRUIT TOUTES LES MACHINES puis les reconstruit, sans aucune commande ensuite.
# Mesure la durée de chaque phase, puis vérifie que la plateforme répond.
# Journal complet de Vagrant et synthèse dans tests/resultats/.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

HORODATAGE=$(date +%Y%m%d_%H%M%S)
SORTIE="tests/resultats/v5_${HORODATAGE}.log"
JOURNAL="tests/resultats/v5_${HORODATAGE}_vagrant.log"
mkdir -p tests/resultats

echo "V5 — $(date '+%d/%m/%Y %H:%M:%S') — vagrant destroy -f puis vagrant up" | tee "$SORTIE"
grep -E '^(GROUPE|NB_APP|E1_LB2|E2_OBS)=' .env | tr '\n' ' ' | sed 's/^/Paramètres : /' | tee -a "$SORTIE"; echo | tee -a "$SORTIE"

T0=$(date +%s)
vagrant destroy -f >> "$JOURNAL" 2>&1
T1=$(date +%s)
vagrant up >> "$JOURNAL" 2>&1
CODE_UP=$?
T2=$(date +%s)

VIP=$(sed -n 's/.*"vip": *"\([^"]*\)".*/\1/p' config/plateforme.json)
{
  echo "destroy -f : $(( T1 - T0 )) s"
  echo "up         : $(( T2 - T1 )) s (code de retour ${CODE_UP})"
  echo "TOTAL      : $(( T2 - T0 )) s ($(( (T2 - T0) / 60 )) min $(( (T2 - T0) % 60 )) s)"
  echo "Machines en marche : $(vagrant status --machine-readable | awk -F, '$3 == "state" && $4 == "running"' | wc -l)"
  echo "/sante    → $(curl -s --max-time 5 -w ' [%{http_code}]' "http://${VIP}/sante")"
  echo "/resultat → $(curl -s --max-time 5 -w ' [%{http_code}]' "http://${VIP}/resultat?matricule=BF000123")"
  echo "Erreurs dans le journal Vagrant : $(grep -ciE 'ÉCHEC|error|non-zero exit' "$JOURNAL")"
} | tee -a "$SORTIE"
echo "Résultat brut : ${SORTIE} (journal complet : ${JOURNAL})"
