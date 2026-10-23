# Service applicatif RÉSULTATS-BF

Responsable : **KOBENDE Pêgdwendé Evrard** (ingénieur applicatif)

Un seul fichier `app.py`, en **Python 3**, de **moins de 100 lignes**. Il utilise uniquement la
bibliothèque standard (`http.server.ThreadingHTTPServer`) et `psycopg2`, installé par apt
(`python3-psycopg2`) : aucun `pip`, pour que le provisionnement fonctionne derrière une connexion lente.

## Points d'entrée (contrat imposé par l'énoncé)

| Requête | Réponse |
|---|---|
| `GET /resultat?matricule=BF000123` | `200` + JSON `{matricule, nom, serie, moyenne, admis}` ; `400` si le matricule est absent ; `404` s'il est inconnu ; `503` si la base ne répond pas |
| `GET /sante` | `200` seulement si `SELECT 1` réussit sur la base, `503` sinon. **Jamais 200 « par principe »** |
| `GET /info` | `200` + JSON `{"serveur": "<nom d'hôte>"}` |

## Règles

- **Sans état** : aucune session, aucun fichier local, aucun compteur. Tout vit dans la base.
- Écoute sur **`0.0.0.0:3000`** (jamais 127.0.0.1).
- Configuration **uniquement** par les variables d'environnement `PG_HOTES`, `PG_BASE`, `PG_UTIL`
  et `PG_MDP`. Aucun mot de passe dans le code.
- Chaîne de connexion avec bascule automatique :
  `host=<bdd1>,<bdd2> dbname=… user=… password=… connect_timeout=2 target_session_attrs=read-write`.
  Avant la bascule, aucune base n'accepte les écritures, donc `/sante` renvoie 503. Après
  `pg_promote()` sur bdd2, la même chaîne trouve bdd2 et `/sante` repasse à 200. L'application n'a rien à modifier.
- Une base absente au démarrage **ne fait pas planter** le service : chaque requête retente la connexion.
- Toute erreur de base est capturée et transformée en réponse JSON `503` propre (jamais de trace brute).
- Fermer chaque connexion après usage, ou utiliser un petit pool qui se reconnecte.

## Test rapide

```bash
vagrant ssh app1 -c "curl -s localhost:3000/info; curl -s -o /dev/null -w '%{http_code}\n' localhost:3000/sante"
```
