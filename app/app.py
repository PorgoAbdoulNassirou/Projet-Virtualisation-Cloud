#!/usr/bin/env python3
"""Service RÉSULTATS-BF : consultation des résultats du baccalauréat, sans état."""
import json
import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

import psycopg2

# Configuration uniquement par l'environnement (fichier /etc/resultats-bf/app.env).
# PG_HOTES vaut "<ip bdd1>,<ip bdd2>" : libpq essaie les hôtes dans l'ordre et ne garde
# que celui qui accepte les écritures (le primaire), d'où la bascule sans modification.
PARAMETRES = {
    "host": os.environ.get("PG_HOTES", "localhost"),
    "dbname": os.environ.get("PG_BASE", "resultats"),
    "user": os.environ.get("PG_UTIL", "app_resultats"),
    "password": os.environ.get("PG_MDP", ""),
    "connect_timeout": 2,
    "target_session_attrs": "read-write",
    "options": "-c statement_timeout=2000",
}
SERVEUR = socket.gethostname()


def interroger(requete, valeurs=()):
    """Ouvre une connexion, exécute la requête, referme toujours la connexion."""
    connexion = psycopg2.connect(**PARAMETRES)
    try:
        with connexion.cursor() as curseur:
            curseur.execute(requete, valeurs)
            return curseur.fetchone()
    finally:
        connexion.close()


class Gestionnaire(BaseHTTPRequestHandler):
    def repondre(self, code, contenu):
        corps = json.dumps(contenu, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(corps)))
        self.end_headers()
        self.wfile.write(corps)

    def do_GET(self):
        url = urlparse(self.path)
        try:
            if url.path == "/info":
                self.repondre(200, {"serveur": SERVEUR})
            elif url.path == "/sante":
                interroger("SELECT 1")
                self.repondre(200, {"etat": "ok", "serveur": SERVEUR})
            elif url.path == "/resultat":
                self.resultat(parse_qs(url.query).get("matricule", [""])[0].strip())
            else:
                self.repondre(404, {"erreur": "point d'entrée inconnu"})
        except psycopg2.Error:
            # Base injoignable, en lecture seule ou trop lente : réponse propre, sans trace.
            self.repondre(503, {"erreur": "base de données indisponible", "serveur": SERVEUR})

    def resultat(self, matricule):
        if not matricule:
            self.repondre(400, {"erreur": "paramètre matricule manquant"})
            return
        ligne = interroger(
            "SELECT matricule, nom, serie, moyenne, admis FROM resultats WHERE matricule = %s",
            (matricule,),
        )
        if ligne is None:
            self.repondre(404, {"erreur": "matricule inconnu", "matricule": matricule})
            return
        self.repondre(200, {
            "matricule": ligne[0],
            "nom": ligne[1],
            "serie": ligne[2],
            "moyenne": float(ligne[3]) if ligne[3] is not None else None,
            "admis": ligne[4],
            "serveur": SERVEUR,
        })

    def log_message(self, format, *args):
        pass  # pas de journal d'accès ligne par ligne : HAProxy le fait déjà


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 3000), Gestionnaire).serve_forever()
