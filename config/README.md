# config/

- `plateforme.json` et `noeuds.yml` sont **engendrés par le Vagrantfile** à chaque commande `vagrant`
  depuis la table `NOEUDS`. Ils ne sont pas versionnés (ils dépendent de `NB_APP`), et il ne faut
  jamais les modifier à la main.
- Dans les machines virtuelles, ils sont lus dans `/vagrant/config/`, toujours via
  `scripts/plateforme.py` (fonction `plateforme` de `scripts/lib.sh`).
- `grafana/` (extension E2, THIOMBIANO) contiendra la source de données et le tableau de bord
  provisionnés automatiquement.
