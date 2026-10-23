#!/usr/bin/env bash
# =============================================================================
# Procédure de bascule de la base (R6, scénario V4) — chronométrée
# Responsable : OUEDRAOGO Armand Hendrix (ingénieur données)
#
# Exécution (depuis l'hôte, à la racine du dépôt) :
#   time vagrant ssh bdd2 -c "sudo bash /vagrant/scripts/bascule_bdd.sh"
#
# CONTRAT :
#   1. vérifier que bdd1 est réellement injoignable (éviter deux primaires)
#   2. promouvoir bdd2 : sudo -u postgres psql -c "SELECT pg_promote();"
#   3. attendre que pg_is_in_recovery() renvoie false
#   4. afficher l'heure de début, de fin et la durée en secondes
# Les applications n'ont RIEN à changer : leur chaîne de connexion liste
# bdd1 ET bdd2 avec target_session_attrs=read-write (voir contrat applicatif).
# =============================================================================
set -euo pipefail
source /vagrant/scripts/lib.sh

journal "TODO (OUEDRAOGO) : procédure de bascule"
