#!/usr/bin/env python3
"""Engendre la configuration de HAProxy et de keepalived depuis config/plateforme.json.

Responsable : PORGO Abdoul Nassirou

Exigence R3 : la liste des serveurs applicatifs n'est JAMAIS écrite en dur ;
elle provient de la même table que le Vagrantfile (NB_APP).

Usage :
  generer_config_lb.py haproxy    --ip IP_DU_LB [--promex]
  generer_config_lb.py keepalived --nom lb1 --ip IP_DU_LB --iface enp0s8
                                  (mot de passe VRRP lu dans $VRRP_MDP)
"""
import argparse
import json
import os
import sys

CHEMIN = os.environ.get("PLATEFORME_JSON", "/vagrant/config/plateforme.json")
ENTETE = "# Fichier ENGENDRÉ par scripts/generer_config_lb.py — ne pas modifier à la main.\n"


def haproxy(p, ip_lb, promex):
    applis = [n for n in p["noeuds"] if n["role"] == "app"]
    serveurs = "\n".join(
        f"    server {n['nom']} {n['ip']}:{p['port_app']} check" for n in applis
    )
    metriques = (
        "    http-request use-service prometheus-exporter if { path /metrics }\n"
        if promex else ""
    )
    return f"""{ENTETE}
global
    log /dev/log local0
    maxconn 4096
    user haproxy
    group haproxy
    daemon
    stats socket /run/haproxy/admin.sock mode 660 level admin

defaults
    mode http
    log global
    option httplog
    option dontlognull
    option forwardfor
    # Une requête envoyée à un serveur qui vient de tomber est rejouée
    # sur un autre serveur (GET idempotents) : aucune erreur visible.
    option redispatch
    retries 2
    retry-on conn-failure empty-response response-timeout
    timeout connect 1s
    timeout client  30s
    timeout server  5s
    timeout check   1s
    # R4 : sonde toutes les secondes, serveur écarté après 2 échecs (< 5 s),
    # réintégré après 2 succès.
    default-server inter 1s fastinter 500ms downinter 2s fall 2 rise 2

frontend entree_http
    bind *:80
    # Santé du répartiteur lui-même (utile pour keepalived et les tests).
    http-request return status 200 content-type text/plain string "repartiteur operationnel" if {{ path /lb-sante }}
    default_backend serveurs_applicatifs

backend serveurs_applicatifs
    balance roundrobin
    option httpchk
    http-check send meth GET uri /sante
    http-check expect status 200
    # Indique quel serveur a répondu (scénario V1).
    http-response set-header X-Serveur %[srv_name]
    http-response set-header Cache-Control no-store
{serveurs}

# Statistiques et métriques, sur le réseau privé uniquement (R8).
listen statistiques
    bind {ip_lb}:8404
    stats enable
    stats uri /stats
    stats refresh 2s
{metriques}"""


def keepalived(p, nom, ip_lb, iface, mdp):
    lbs = [n for n in p["noeuds"] if n["role"] == "lb"]
    rang = [n["nom"] for n in lbs].index(nom)
    priorite = 150 - 50 * rang                    # lb1 → 150, lb2 → 100
    pairs = "\n".join(f"        {n['ip']}" for n in lbs if n["nom"] != nom)
    return f"""{ENTETE}
global_defs {{
    router_id {nom}
    enable_script_security
    script_user root
}}

# L'IP virtuelle quitte une machine dont HAProxy est arrêté.
vrrp_script verifier_haproxy {{
    script "/usr/bin/systemctl is-active --quiet haproxy"
    interval 1
    fall 2
    rise 2
}}

vrrp_instance VI_RESULTATS {{
    # Les deux répartiteurs démarrent en BACKUP : la priorité décide du
    # maître, et preempt_delay laisse lb1 se stabiliser avant de reprendre l'IP.
    state BACKUP
    interface {iface}
    virtual_router_id {50 + p['groupe']}
    priority {priorite}
    advert_int 1
    preempt_delay 10
    # Unicast : ne dépend pas du multicast sur le réseau hôte-seul.
    unicast_src_ip {ip_lb}
    unicast_peer {{
{pairs}
    }}
    authentication {{
        auth_type PASS
        auth_pass {mdp}
    }}
    virtual_ipaddress {{
        {p['vip']}/24 dev {iface}
    }}
    track_script {{
        verifier_haproxy
    }}
}}
"""


def main():
    a = argparse.ArgumentParser()
    a.add_argument("cible", choices=["haproxy", "keepalived"])
    a.add_argument("--ip", required=True)
    a.add_argument("--nom")
    a.add_argument("--iface")
    a.add_argument("--promex", action="store_true")
    args = a.parse_args()
    with open(CHEMIN, encoding="utf-8") as f:
        p = json.load(f)
    if args.cible == "haproxy":
        sys.stdout.write(haproxy(p, args.ip, args.promex))
    else:
        mdp = os.environ.get("VRRP_MDP", "")
        if not mdp or len(mdp) > 8:
            sys.exit("VRRP_MDP absent ou trop long (8 caractères maximum)")
        sys.stdout.write(keepalived(p, args.nom, args.ip, args.iface, mdp))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
