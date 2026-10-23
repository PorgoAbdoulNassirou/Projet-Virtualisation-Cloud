#!/usr/bin/env bash
# =============================================================================
# Rôle « bdd » (bdd1) — PostgreSQL primaire, lecture et écriture
# Responsable : OUEDRAOGO Armand Hendrix (ingénieur données)
#
# CONTRAT (voir docs/PLAN_DE_TRAVAIL.md, section « Contrats d'interface ») :
#   - PostgreSQL de la distribution (16 sur Ubuntu 24.04), données dans
#     /var/lib/postgresql — JAMAIS dans /vagrant (dossier synchronisé)
#   - écoute sur toutes les interfaces (listen_addresses = '*'), port 5432
#   - pg_hba : accès limité au réseau $(plateforme valeur reseau), scram-sha-256
#   - base « resultats », table resultats(matricule, nom, serie, moyenne, admis)
#     50 000 lignes via generate_series ; matricule au format BF000001
#   - rôle « app_resultats » (SELECT seulement), mot de passe $PG_MDP_APP
#   - rôle « replicateur » (REPLICATION), mot de passe $PG_MDP_REPLICATION
#   - idempotent : CREATE … IF NOT EXISTS, fichiers dans conf.d, aucun « >> »
#
# Modèle conseillé : scripts de l'atelier 3 (bdd.sh).
# =============================================================================
set -euo pipefail
source /vagrant/scripts/lib.sh

journal "TODO (OUEDRAOGO) : installer et configurer PostgreSQL primaire"
