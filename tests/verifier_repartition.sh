#!/usr/bin/env bash
# =============================================================================
# Vérification des exigences du domaine « réseau et répartition »
# Auteur : PORGO Abdoul Nassirou
#
# À lancer DEPUIS L'HÔTE (Git Bash), à la racine du dépôt :
#   bash tests/verifier_repartition.sh r8     seul lb1 expose un port vers l'hôte
#   bash tests/verifier_repartition.sh r2     provisionnement rejoué deux fois → rien ne change
#   bash tests/verifier_repartition.sh r3     serveurs connus de HAProxy = NB_APP
#   bash tests/verifier_repartition.sh r4     délai d'éviction d'un serveur défaillant
#   bash tests/verifier_repartition.sh tout
# Résultat brut enregistré dans tests/resultats/.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

PREFIXE=$(sed -n 's/.*"prefixe": *"\([^"]*\)".*/\1/p' config/plateforme.json)
STATS="http://${PREFIXE}.11:8404/stats;csv"
SORTIE="tests/resultats/repartition_$(date +%Y%m%d_%H%M%S).log"
mkdir -p tests/resultats
exec > >(tee -a "$SORTIE") 2>&1

machines() { vagrant status --machine-readable | awk -F, '$3 == "state" && $4 == "running" {print $2}'; }

# Empreinte des fichiers que le provisionnement est susceptible de modifier.
empreinte() {
  vagrant ssh "$1" -c "sudo sha256sum /etc/hosts /etc/haproxy/haproxy.cfg /etc/keepalived/keepalived.conf 2>/dev/null" 2>/dev/null | tr -d '\r'
}

r8() {
  echo "### R8 — ports exposés vers l'hôte"
  for m in $(machines); do
    echo "$m : $(vagrant port "$m" 2>/dev/null | tr -d '\r' | awk '/=>/ {printf "%s ", $0}')"
  done
  echo "→ attendu : 22 => 2222… (SSH Vagrant) partout, et 80 => 8080 uniquement sur lb1"
}

r2() {
  echo "### R2 — idempotence (vagrant provision rejoué deux fois)"
  local m avant apres ko=0
  for m in $(machines); do
    vagrant provision "$m" >/dev/null 2>&1 || { echo "$m : ÉCHEC du 1er provisionnement"; ko=1; continue; }
    avant=$(empreinte "$m")
    vagrant provision "$m" >/dev/null 2>&1 || { echo "$m : ÉCHEC du 2e provisionnement"; ko=1; continue; }
    apres=$(empreinte "$m")
    if [ "$avant" = "$apres" ]; then echo "$m : identique ✔"; else echo "$m : MODIFIÉ ✘"; ko=1; fi
  done
  [ "$ko" = 0 ] && echo "→ R2 satisfaite" || echo "→ R2 NON satisfaite"
}

r3() {
  echo "### R3 — serveurs déclarés dans HAProxy"
  local attendus declares
  attendus=$(grep -c '"role": "app"' config/plateforme.json)
  declares=$(curl -s "$STATS" | awk -F, '$1 == "serveurs_applicatifs" && $2 ~ /^app/ {print $2 " " $18}')
  echo "$declares"
  echo "→ NB_APP = ${attendus}, serveurs dans HAProxy = $(echo "$declares" | grep -c app)"
}

r4() {
  echo "### R4 — éviction d'un serveur défaillant (app1 arrêté brutalement)"
  local debut fin etat
  vagrant ssh app1 -c "sudo systemctl stop resultats-app" >/dev/null 2>&1
  debut=$(date +%s%3N)
  while :; do
    etat=$(curl -s "$STATS" | awk -F, '$2 == "app1" {print $18}')
    case "$etat" in DOWN*|MAINT*) break ;; esac
    if (( $(date +%s%3N) - debut > 15000 )); then echo "app1 toujours ${etat} après 15 s ✘"; break; fi
    sleep 0.2
  done
  fin=$(date +%s%3N)
  echo "app1 écarté (${etat}) en $(( fin - debut )) ms → exigence : < 5000 ms"
  vagrant ssh app1 -c "sudo systemctl start resultats-app" >/dev/null 2>&1
}

echo "== Vérification répartition — $(date '+%d/%m/%Y %H:%M:%S') — groupe réseau ${PREFIXE}.0/24"
case "${1:-tout}" in
  r2) r2 ;; r3) r3 ;; r4) r4 ;; r8) r8 ;;
  tout) r8; r3; r4; r2 ;;
  *) echo "usage : $0 [r2|r3|r4|r8|tout]"; exit 1 ;;
esac
echo "Résultat brut : ${SORTIE}"
