#!/usr/bin/env bash
# =============================================================================
# Rôle « lb » (lb1, lb2) — HAProxy + keepalived (extension E1)
# Responsable : PORGO Abdoul Nassirou
#
# Rejoué à chaque « vagrant up » (run: always) : après NB_APP=4 vagrant up, la
# configuration est réengendrée et HAProxy rechargé sans coupure (R3).
# Idempotent : si rien n'a changé, aucun fichier n'est réécrit et aucun service
# n'est rechargé (R2).
# =============================================================================
set -euo pipefail
source /vagrant/scripts/lib.sh

NOM=$(hostname -s)
MON_IP=$(plateforme ip "$NOM")
E1=$(plateforme valeur extensions.e1_lb2)

paquets=(haproxy)
[ "$E1" = "1" ] && paquets+=(keepalived)
installer_paquets "${paquets[@]}"

# --- HAProxy -----------------------------------------------------------------
OPTIONS=(--ip "$MON_IP")
# Exportateur Prometheus intégré (utile pour E2), seulement s'il est compilé.
# Sortie capturée d'abord : « haproxy -vv | grep -q » échoue sous pipefail
# (grep -q ferme le tube, haproxy reçoit SIGPIPE).
VERSION_HAPROXY=$(haproxy -vv 2>&1 || true)
[[ "$VERSION_HAPROXY" == *"+PROMEX"* ]] && OPTIONS+=(--promex)

NOUVEAU=$(mktemp)
python3 /vagrant/scripts/generer_config_lb.py haproxy "${OPTIONS[@]}" > "$NOUVEAU"
# Une configuration invalide arrête le provisionnement AVANT d'être installée.
haproxy -c -q -f "$NOUVEAU"

systemctl enable --quiet haproxy
if installer_si_change "$NOUVEAU" /etc/haproxy/haproxy.cfg 644; then
  # reload : les connexions en cours sont conservées (aucune coupure).
  systemctl reload-or-restart haproxy
  journal "HAProxy reconfiguré : $(plateforme role app | wc -l) serveur(s) applicatif(s)"
else
  journal "HAProxy inchangé"
fi
systemctl is-active --quiet haproxy || systemctl start haproxy

# --- keepalived (E1) ---------------------------------------------------------
if [ "$E1" = "1" ]; then
  # Interface portant l'adresse privée (enp0s8 en général, mais on ne suppose rien).
  IFACE=$(ip -o -4 addr show | awk -v ip="$MON_IP" '{split($4, a, "/"); if (a[1] == ip) print $2}')
  [ -n "$IFACE" ] || { journal "ÉCHEC : interface de ${MON_IP} introuvable"; exit 1; }

  NOUVEAU=$(mktemp)
  python3 /vagrant/scripts/generer_config_lb.py keepalived \
    --nom "$NOM" --ip "$MON_IP" --iface "$IFACE" > "$NOUVEAU"

  systemctl enable --quiet keepalived
  # Mode 600 : le fichier contient le mot de passe VRRP.
  if installer_si_change "$NOUVEAU" /etc/keepalived/keepalived.conf 600; then
    systemctl restart keepalived
    journal "keepalived reconfiguré (IP virtuelle $(plateforme valeur vip) sur ${IFACE})"
  else
    journal "keepalived inchangé"
  fi
  systemctl is-active --quiet keepalived || systemctl start keepalived
fi

journal "répartiteur prêt — statistiques : http://${MON_IP}:8404/stats"
