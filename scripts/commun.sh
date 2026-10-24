#!/usr/bin/env bash
# =============================================================================
# Socle commun à TOUTES les machines — rejoué à chaque « vagrant up »
# Responsable : PORGO Abdoul Nassirou
#
# - paquets de base groupés en un seul appel apt
# - fuseau horaire (horodatage cohérent des mesures entre machines)
# - bloc /etc/hosts engendré depuis config/plateforme.json
# - node_exporter si l'extension E2 est active (THIOMBIANO, rotation)
# Idempotent : rejoué deux fois, il ne modifie rien.
# =============================================================================
set -euo pipefail
source /vagrant/scripts/lib.sh

E2=$(plateforme valeur extensions.e2_obs)

paquets=(python3 curl ca-certificates)
[ "$E2" = "1" ] && paquets+=(prometheus-node-exporter)
installer_paquets "${paquets[@]}"

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
# Écoute sur le port 9100 de toutes les interfaces : obs le collecte par le
# réseau privé (cibles engendrées par obs.sh depuis la même table).
if [ "$E2" = "1" ]; then
  systemctl enable --quiet prometheus-node-exporter
  systemctl is-active --quiet prometheus-node-exporter || systemctl start prometheus-node-exporter
fi

journal "socle commun prêt"
