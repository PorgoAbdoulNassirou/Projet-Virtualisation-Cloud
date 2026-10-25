# Installation du poste : tout ce qu'il faut installer

Ce document liste **tout** ce que chaque membre doit installer sur son ordinateur (Windows) pour
travailler sur RÉSULTATS-BF. **Rien n'est à installer à la main dans les machines virtuelles** : les
scripts de provisionnement s'en chargent (c'est l'exigence R1).

Les versions sont **épinglées** : ce sont celles avec lesquelles la plateforme a été validée le 23/10/2026.
Tout le groupe utilise les mêmes, pour éviter le « ça marche chez moi ».

---

## 1. Vérifier le poste

| Exigence | Comment vérifier |
|---|---|
| Windows 10 ou 11, 64 bits | Paramètres → Système → Informations |
| **8 Go de RAM minimum** (16 Go conseillés) | Gestionnaire des tâches → Performances → Mémoire |
| **20 Go libres** sur le disque C: | Explorateur → Ce PC |
| **Virtualisation activée** dans le BIOS (VT-x / AMD-V) | Gestionnaire des tâches → Performances → Processeur → « Virtualisation : Activé ». Sinon, l'activer dans le BIOS/UEFI |

> Docker Desktop, WSL2 ou Hyper-V peuvent rester installés : VirtualBox 7 fonctionne avec eux,
> mais les VM sont plus lentes. Fermer Docker Desktop pendant les tests libère de la mémoire.

---

## 2. Outils communs à TOUS les membres

Ouvrir **PowerShell en administrateur** (clic droit → « Exécuter en tant qu'administrateur »), puis :

```powershell
winget install --id Oracle.VirtualBox     -e --version 7.2.6  --accept-package-agreements --accept-source-agreements
winget install --id Hashicorp.Vagrant     -e --version 2.4.9  --accept-package-agreements --accept-source-agreements
winget install --id Git.Git               -e                  --accept-package-agreements --accept-source-agreements
```

| Outil | Version | Rôle dans le projet |
|---|---|---|
| Oracle VirtualBox | **7.2.6** | Hyperviseur de type 2 qui exécute les VM |
| HashiCorp Vagrant | **2.4.9** | Crée et provisionne les VM à partir du `Vagrantfile` |
| Git (avec **Git Bash**) | dernière | Dépôt partagé ; Git Bash fournit `bash`, `curl`, `sed`, `awk` pour les scripts de `tests/` |

**Redémarrer l'ordinateur** après l'installation de VirtualBox et de Vagrant (pilotes réseau et `PATH`).

### Vérification

Dans **Git Bash** :

```bash
vagrant --version                                         # Vagrant 2.4.9
"/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" --version   # 7.2.6r…
git --version
```

### Configuration de Git (une seule fois)

```bash
git config --global user.name  "Prénom NOM"              # VOTRE nom : l'historique prouve qui a fait quoi
git config --global user.email "adresse@du.compte.github"
git config --global core.autocrlf false                   # le .gitattributes impose LF
```

### Premier lancement

```bash
git clone https://github.com/PorgoAbdoulNassirou/Projet-Virtualisation-Cloud.git resultats-bf
cd resultats-bf
vagrant up          # 1er lancement : télécharge la box bento/ubuntu-24.04 202510.26.0 (≈ 1 Go)
```

Prévoir **25 minutes** et une connexion stable pour le premier `vagrant up` complet.

---

## 3. Outils supplémentaires selon le rôle

| Membre | Outil en plus | Pourquoi |
|---|---|---|
| PORGO, KOBENDE, OUEDRAOGO | aucun | — |
| **THIOMBIANO** | **Apache Bench (`ab`)** | Scénario V3 : `ab -n 2000 -c 50` |
| **THIOMBIANO** | **Pandoc** | Conversion du dossier Markdown en Word/PDF |

### Apache Bench (`ab`) sous Windows

`ab` n'existe pas dans winget : il est fourni avec le serveur Apache httpd d'Apache Lounge.

1. Installer le runtime Visual C++ (requis par `ab.exe`) :
   ```powershell
   winget install --id Microsoft.VCRedist.2015+.x64 -e --accept-package-agreements --accept-source-agreements
   ```
2. Télécharger l'archive **httpd-2.4.x-win64-VS17.zip** sur https://www.apachelounge.com/download/
3. Extraire seulement `Apache24\bin\ab.exe` (et les `.dll` du même dossier) dans `C:\outils\ab\`
4. Ajouter `C:\outils\ab` au `PATH` (Paramètres → Système → Informations → Paramètres avancés →
   Variables d'environnement), puis rouvrir Git Bash.
5. Vérifier : `ab -V`

### Pandoc

```powershell
winget install --id JohnMacFarlane.Pandoc -e --accept-package-agreements --accept-source-agreements
```

Conversion du dossier : `pandoc docs/dossier_architecture.md -o dossier_architecture.docx`

---

## 4. Ce qui s'installe AUTOMATIQUEMENT dans les VM (pour information)

Personne ne l'installe à la main : c'est le provisionnement qui le fait, à chaque `vagrant up`.

| Machine | Paquets (Ubuntu 24.04) | Script |
|---|---|---|
| toutes | `python3`, `curl`, `ca-certificates` (+ `prometheus-node-exporter` si E2) | `scripts/commun.sh` |
| lb1, lb2 | `haproxy` 2.8, `keepalived` 2.2 | `scripts/lb.sh` |
| app1 … appN | `python3-psycopg2` | `scripts/app.sh` |
| bdd1, bdd2 | `postgresql` 16 | `scripts/bdd.sh`, `scripts/replique.sh` |
| obs | `prometheus` ; `grafana` 13.2.4 (paquet `.deb` de dl.grafana.com, empreinte SHA-256 vérifiée, mis en cache dans `.cache/` du projet : téléchargé une seule fois, ≈ 380 Mo) | `scripts/obs.sh` |

**Règle pour tout nouveau besoin** : un paquet nécessaire dans une VM s'ajoute dans le script du rôle,
avec `installer_paquets` (un seul appel par script), et ce tableau est mis à jour. Un outil nécessaire sur
l'hôte s'ajoute à la section 2 ou 3 de ce document. **Rien ne doit être installé « à la main » sans être écrit ici.**

---

## 5. Problèmes fréquents à l'installation

| Symptôme | Solution |
|---|---|
| `VT-x is not available` / la VM ne démarre pas | Activer la virtualisation dans le BIOS/UEFI |
| `vagrant` introuvable dans Git Bash | Redémarrer l'ordinateur (le `PATH` n'est pas encore à jour) |
| Vagrant refuse la version de VirtualBox | Installer exactement les versions de la section 2 |
| `The IP address configured for the host-only network is not within the allowed ranges` | Ne jamais modifier `GROUPE` (04) ni le réseau dans le `Vagrantfile` |
| Le premier `vagrant up` échoue au téléchargement de la box | Connexion coupée : relancer `vagrant up` |
