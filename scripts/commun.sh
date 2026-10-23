#!/usr/bin/env bash
# =============================================================================
# Socle commun à TOUTES les machines — rejoué à chaque « vagrant up »
# Responsable : PORGO Abdoul Nassirou
#
# - paquets de base groupés en un seul appel apt
# - fuseau horaire (horodatage cohérent des mesures entre machines)
# - bloc /etc/hosts engendré depuis config/plateforme.json
# Idempotent : rejoué deux fois, il ne modifie rien.
# =============================================================================
set -euo pipefail
source /vagrant/scripts/lib.sh

installer_paquets python3 curl ca-certificates

if [ "$(timedatectl show -p Timezone --value)" != "Africa/Ouagadougou" ]; then
  timedatectl set-timezone Africa/Ouagadougou
fi

# --- /etc/hosts : bloc géré entre deux marqueurs, réécrit à l'identique ------
DEBUT="# >>> resultats-bf (engendré, ne pas modifier)"
FIN="# <<< resultats-bf"
TMP=$(mktemp)
sed "/^${DEBUT}\$/,/^${FIN}\$/d" /etc/hosts > "$TMP"
{
  echo "$DEBUT"
  plateforme hosts
  echo "$FIN"
} >> "$TMP"
if installer_si_change "$TMP" /etc/hosts 644; then
  journal "/etc/hosts mis à jour"
fi

# --- Extension E2 : node_exporter sur chaque machine -------------------------
# À compléter par l'ingénieur observabilité (THIOMBIANO) : commit hors domaine.
# if [ "${E2_OBS:-0}" = "1" ]; then
#   installer_paquets prometheus-node-exporter
#   systemctl enable --now prometheus-node-exporter
# fi

journal "socle commun prêt"
