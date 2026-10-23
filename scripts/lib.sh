# shellcheck shell=bash
# =============================================================================
# Bibliothèque commune — à charger par « source /vagrant/scripts/lib.sh »
# Responsable : PORGO Abdoul Nassirou
#
# Fonctions utilisables par TOUS les scripts de rôle :
#   journal "message"                     affiche « == [machine] message »
#   plateforme ip bdd1                    lit config/plateforme.json
#   installer_paquets p1 p2 …             apt groupé, seulement si manquants
#   installer_si_change src dest [mode]   remplace dest si différent → code 0
#                                         sinon code 1 (rien n'a changé)
#   attendre_port hote port [delai]       attend qu'un port TCP réponde
# =============================================================================
export DEBIAN_FRONTEND=noninteractive

journal() {
  echo "== [$(hostname -s)] $*"
}

# Accès à la source unique de vérité (config/plateforme.json).
plateforme() {
  python3 /vagrant/scripts/plateforme.py "$@"
}

# Installe uniquement les paquets absents, en un seul appel apt (connexion
# lente : on ne télécharge rien deux fois). L'index apt n'est rafraîchi que
# s'il a plus de 6 heures. DPkg::Lock::Timeout évite l'échec lorsque
# unattended-upgrades tient le verrou juste après le démarrage.
installer_paquets() {
  local manquants=() p
  for p in "$@"; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed" \
      || manquants+=("$p")
  done
  if [ ${#manquants[@]} -eq 0 ]; then
    journal "paquets déjà présents : $*"
    return 0
  fi
  local repere=/var/lib/resultats-bf/apt-update
  mkdir -p "$(dirname "$repere")"
  if [ -z "$(find "$repere" -mmin -360 2>/dev/null)" ]; then
    apt-get -o DPkg::Lock::Timeout=300 update -qq
    touch "$repere"
  fi
  journal "installation : ${manquants[*]}"
  apt-get -o DPkg::Lock::Timeout=300 install -y -qq --no-install-recommends "${manquants[@]}"
}

# Idempotence : on n'écrase un fichier de configuration (et on ne recharge le
# service) que si son contenu a réellement changé.
installer_si_change() {
  local src=$1 dest=$2 mode=${3:-644}
  if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
    rm -f "$src"
    return 1
  fi
  install -D -m "$mode" "$src" "$dest"
  rm -f "$src"
  return 0
}

attendre_port() {
  local hote=$1 port=$2 delai=${3:-120} debut=$SECONDS
  until timeout 2 bash -c "exec 3<>/dev/tcp/${hote}/${port}" 2>/dev/null; do
    if (( SECONDS - debut >= delai )); then
      journal "ÉCHEC : ${hote}:${port} injoignable après ${delai} s"
      return 1
    fi
    sleep 2
  done
}
