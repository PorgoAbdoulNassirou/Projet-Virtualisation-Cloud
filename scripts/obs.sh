#!/usr/bin/env bash
# =============================================================================
# Rôle « obs » — Prometheus + Grafana (extension E2)
# Responsable : THIOMBIANO Yempabou Romaric Johan (ingénieur essais et observabilité)
#
# - Prometheus (paquet Ubuntu) : cibles ENGENDRÉES depuis plateforme.json,
#   comme la configuration du répartiteur (aucune adresse en dur) :
#     node_exporter  <ip>:9100          toutes les machines (installé par commun.sh)
#     HAProxy        <ip lb>:8404/metrics  exportateur intégré de lb1 et lb2
# - Grafana (dépôt apt.grafana.com, ajouté une seule fois) : mot de passe admin
#   $GRAFANA_MDP, source de données et tableau de bord provisionnés depuis
#   /vagrant/config/grafana/ (fichiers, aucun clic)
# - accès depuis l'hôte par le réseau privé : http://<ip obs>:3000
#   (aucun port redirigé : R8)
# Idempotent : fichiers remplacés et services relancés seulement s'ils changent.
# =============================================================================
set -euo pipefail
source /vagrant/scripts/lib.sh

: "${GRAFANA_MDP:?GRAFANA_MDP doit être fourni par Vagrant}"

MON_IP=$(plateforme ip "$(hostname -s)")

# --- Dépôt apt de Grafana (absent d'Ubuntu) ----------------------------------
# Clé au format texte (.asc), qu'apt lit directement : gpg n'est pas nécessaire.
CLE=/etc/apt/keyrings/grafana.asc
if [ ! -s "$CLE" ]; then
  tmp=$(mktemp)
  curl -fsSL https://apt.grafana.com/gpg.key -o "$tmp"
  install -D -m 644 "$tmp" "$CLE"
  rm -f "$tmp"
fi
tmp=$(mktemp)
echo "deb [signed-by=${CLE}] https://apt.grafana.com stable main" > "$tmp"
if installer_si_change "$tmp" /etc/apt/sources.list.d/grafana.list 644; then
  # Nouveau dépôt : forcer le rafraîchissement de l'index (lib.sh ne le fait que toutes les 6 h).
  rm -f /var/lib/resultats-bf/apt-update
fi

installer_paquets prometheus grafana

# --- Prometheus : configuration engendrée ------------------------------------
tmp=$(mktemp)
{
  cat <<'EOF'
# Fichier ENGENDRÉ par scripts/obs.sh depuis config/plateforme.json — ne pas modifier à la main.
global:
  # 5 s : assez fin pour voir un serveur disparaître pendant les scénarios V2 et V3.
  scrape_interval: 5s
  evaluation_interval: 5s

scrape_configs:
  - job_name: node
    static_configs:
EOF
  plateforme hosts | while read -r ip nom; do
    [ "$nom" = "vip" ] && continue
    printf "      - targets: ['%s:9100']\n        labels: {machine: %s}\n" "$ip" "$nom"
  done
  cat <<'EOF'
  - job_name: haproxy
    metrics_path: /metrics
    static_configs:
EOF
  plateforme role lb | while read -r nom ip; do
    printf "      - targets: ['%s:8404']\n        labels: {machine: %s}\n" "$ip" "$nom"
  done
} > "$tmp"
# Une configuration invalide arrête le provisionnement AVANT d'être installée.
promtool check config "$tmp" >/dev/null

systemctl enable --quiet prometheus
if installer_si_change "$tmp" /etc/prometheus/prometheus.yml 644; then
  systemctl reload-or-restart prometheus
  journal "Prometheus reconfiguré : $(plateforme hosts | grep -vc 'vip$') machine(s) surveillée(s)"
else
  journal "Prometheus inchangé"
fi
systemctl is-active --quiet prometheus || systemctl start prometheus

# --- Grafana -----------------------------------------------------------------
redemarrer=0

# Mode 600 : le fichier contient le mot de passe admin. Grafana ne l'applique
# qu'à la création de sa base, donc au premier démarrage de obs.
# Seul le plugin Prometheus sert : les autres sources de données intégrées sont
# chacune un processus, et les charger toutes saturait les 768 Mo de obs
# (premier démarrage mesuré à 10 min). Aucun téléchargement de plugin au démarrage.
tmp=$(mktemp)
cat > "$tmp" <<EOF
GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_MDP}
GF_ANALYTICS_REPORTING_ENABLED=false
GF_ANALYTICS_CHECK_FOR_UPDATES=false
GF_ANALYTICS_CHECK_FOR_PLUGIN_UPDATES=false
GF_PLUGINS_PREINSTALL_DISABLED=true
GF_PLUGINS_DISABLE_PLUGINS=elasticsearch,grafana-postgresql-datasource,grafana-pyroscope-datasource,influxdb,jaeger,loki,mssql,mysql,opentsdb,stackdriver,tempo,zipkin,grafana-exploretraces-app,grafana-lokiexplore-app,grafana-pyroscope-app,grafana-metricsdrilldown-app
EOF
if installer_si_change "$tmp" /etc/resultats-bf/grafana.env 600; then redemarrer=1; fi

tmp=$(mktemp)
cat > "$tmp" <<'EOF'
[Service]
EnvironmentFile=/etc/resultats-bf/grafana.env
EOF
if installer_si_change "$tmp" /etc/systemd/system/grafana-server.service.d/resultats-bf.conf 644; then
  systemctl daemon-reload
  redemarrer=1
fi

# Source de données et tableau de bord : fichiers du dépôt, jamais de clic.
for f in datasource.yml:/etc/grafana/provisioning/datasources/resultats-bf.yml \
         tableaux.yml:/etc/grafana/provisioning/dashboards/resultats-bf.yml \
         tableau_plateforme.json:/var/lib/grafana/dashboards/resultats-bf/plateforme.json; do
  tmp=$(mktemp)
  cp "/vagrant/config/grafana/${f%%:*}" "$tmp"
  if installer_si_change "$tmp" "${f#*:}" 644; then redemarrer=1; fi
done

systemctl enable --quiet grafana-server
if [ "$redemarrer" -eq 1 ]; then
  systemctl restart grafana-server
  journal "Grafana (re)démarré"
else
  journal "Grafana inchangé"
fi
systemctl is-active --quiet grafana-server || systemctl start grafana-server

attendre_port 127.0.0.1 9090 60
# Le tout premier démarrage crée la base de Grafana (≈ 720 migrations) : délai large.
attendre_port "$MON_IP" 3000 300
journal "supervision prête — Grafana : http://${MON_IP}:3000 (admin / GRAFANA_MDP du .env)," \
        "Prometheus : http://${MON_IP}:9090/targets"
