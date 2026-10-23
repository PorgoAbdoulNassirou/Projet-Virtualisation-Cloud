#!/usr/bin/env python3
"""Lecture de config/plateforme.json, la source unique de vérité engendrée par le Vagrantfile.

Responsable : PORGO Abdoul Nassirou

Usage :
  plateforme.py ip NOM          adresse d'une machine          (ex. ip bdd1)
  plateforme.py role ROLE       « nom ip » de chaque machine   (ex. role app)
  plateforme.py valeur CLE      valeur simple, clés pointées   (ex. valeur vip,
                                                                valeur extensions.e1_lb2)
  plateforme.py hosts           bloc pour /etc/hosts
"""
import json
import os
import sys

CHEMIN = os.environ.get("PLATEFORME_JSON", "/vagrant/config/plateforme.json")


def charger():
    with open(CHEMIN, encoding="utf-8") as f:
        return json.load(f)


def main(args):
    if not args:
        sys.exit(__doc__)
    p = charger()
    commande = args[0]
    if commande == "ip":
        for n in p["noeuds"]:
            if n["nom"] == args[1]:
                print(n["ip"])
                return
        sys.exit(f"machine inconnue : {args[1]}")
    elif commande == "role":
        for n in p["noeuds"]:
            if n["role"] == args[1]:
                print(n["nom"], n["ip"])
    elif commande == "valeur":
        v = p
        for cle in args[1].split("."):
            v = v[cle]
        print(("1" if v else "0") if isinstance(v, bool) else v)
    elif commande == "hosts":
        for n in p["noeuds"]:
            print(f"{n['ip']}\t{n['nom']}")
        print(f"{p['vip']}\tvip")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main(sys.argv[1:])
