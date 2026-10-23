#!/usr/bin/env bash
# =============================================================================
# Rôle « replique » (bdd2) — réplique en flux (streaming replication) de bdd1
# Responsable : OUEDRAOGO Armand Hendrix (ingénieur données)
#
# CONTRAT :
#   - attendre que bdd1 réponde : attendre_port "$(plateforme ip bdd1)" 5432
#   - si la machine n'est pas déjà une réplique (pas de standby.signal) :
#       arrêter PostgreSQL, vider le répertoire de données,
#       pg_basebackup -h bdd1 -U replicateur -R -X stream (PGPASSWORD)
#   - rejoué : ne refait PAS le pg_basebackup (idempotence R2)
#   - même pg_hba et listen_addresses que bdd1 (elle doit pouvoir être promue)
#   - vérification R5 : une ligne insérée sur bdd1 est lisible sur bdd2
# =============================================================================
set -euo pipefail
source /vagrant/scripts/lib.sh

journal "TODO (OUEDRAOGO) : configurer la réplique en flux"
