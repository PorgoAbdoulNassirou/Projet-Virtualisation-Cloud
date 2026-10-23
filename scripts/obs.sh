#!/usr/bin/env bash
# =============================================================================
# Rôle « obs » — Prometheus + Grafana (extension E2)
# Responsable : THIOMBIANO Yempabou Romaric Johan (ingénieur essais et observabilité)
#
# CONTRAT :
#   - Prometheus (paquet « prometheus ») ; cibles ENGENDRÉES depuis plateforme.json :
#       node_exporter  <ip>:9100  sur toutes les machines
#       HAProxy        <ip lb>:8404/metrics  (exportateur intégré)
#     → pas d'adresse en dur, comme pour le répartiteur
#   - Grafana (dépôt apt.grafana.com, ajouté de façon idempotente),
#     mot de passe admin $GRAFANA_MDP, source de données et tableau de bord
#     provisionnés depuis /vagrant/config/grafana/ (fichiers, pas de clic)
#   - accès depuis l'hôte par le réseau privé : http://<ip obs>:3000
#     (pas de port redirigé : R8)
#   - tableau de bord : débit par serveur, serveurs UP/DOWN, CPU par machine
# =============================================================================
set -euo pipefail
source /vagrant/scripts/lib.sh

journal "TODO (THIOMBIANO) : Prometheus et Grafana"
