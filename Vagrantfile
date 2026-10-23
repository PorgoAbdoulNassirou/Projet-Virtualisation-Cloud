# -*- mode: ruby -*-
# vi: set ft=ruby :
# =============================================================================
# RÉSULTATS-BF — infrastructure résiliente et scalable, entièrement en code
# Responsable : PORGO Abdoul Nassirou (architecte réseau et répartition)
#
# Source unique de vérité (exigence R3) : la table NOEUDS ci-dessous décrit les
# machines virtuelles ET engendre config/plateforme.json (et config/noeuds.yml).
# Tous les scripts de provisionnement lisent ce fichier : HAProxy, keepalived,
# /etc/hosts, Prometheus… Aucune adresse n'est écrite en dur ailleurs.
#
#   vagrant up                 → plateforme complète
#   NB_APP=4 vagrant up        → 4 serveurs applicatifs, répartiteur reconfiguré
# =============================================================================
require "json"
require "yaml"
require "fileutils"
require "securerandom"

RACINE = File.expand_path(File.dirname(__FILE__))

# --- .env : paramètres et secrets (R7) ----------------------------------------
# Le .env n'est jamais versionné. Sur un clone neuf il n'existe pas : il est
# alors créé à partir de .env.exemple avec des mots de passe aléatoires, sans
# aucun geste manuel (R1).
FICHIER_ENV     = File.join(RACINE, ".env")
FICHIER_EXEMPLE = File.join(RACINE, ".env.exemple")
unless File.exist?(FICHIER_ENV)
  modele = File.binread(FICHIER_EXEMPLE)
  modele = modele.gsub("__ALEATOIRE8__") { SecureRandom.alphanumeric(8) }
  modele = modele.gsub("__ALEATOIRE__")  { SecureRandom.alphanumeric(24) }
  File.binwrite(FICHIER_ENV, modele)
end

def lire_env(chemin)
  File.binread(chemin).split("\n").each_with_object({}) do |ligne, h|
    ligne = ligne.strip
    next if ligne.empty? || ligne.start_with?("#") || !ligne.include?("=")
    cle, val = ligne.split("=", 2)
    h[cle.strip] = val.strip.delete_prefix('"').delete_suffix('"')
  end
end
DOTENV = lire_env(FICHIER_ENV)

# Une variable du shell (ex. NB_APP=4 vagrant up) l'emporte sur le .env.
def param(cle, defaut)
  ENV[cle] || DOTENV[cle] || defaut
end

GROUPE    = param("GROUPE", "1").to_i
NB_APP    = param("NB_APP", "2").to_i
E1_LB2    = param("E1_LB2", "1") == "1"
E2_OBS    = param("E2_OBS", "1") == "1"
PORT_HOTE = param("PORT_HOTE", "8080").to_i

raise "GROUPE doit être compris entre 1 et 8 (reçu : #{GROUPE})" unless (1..8).cover?(GROUPE)
raise "NB_APP doit être compris entre 2 et 9 (reçu : #{NB_APP})" unless (2..9).cover?(NB_APP)

# Plage imposée par VirtualBox >= 6.1.28 : 192.168.56.0/21 → X = 55 + G.
RESEAU  = "192.168.#{55 + GROUPE}"
VIP     = "#{RESEAU}.5"               # IP virtuelle VRRP portée par lb1 ou lb2 (E1)
BOITE   = "bento/ubuntu-24.04"
# Version épinglée, identique pour tout le groupe. La 202404.23.0 du squelette
# de l'énoncé n'est pas publiée pour virtualbox/amd64 : vagrant up échouait.
VERSION = "202510.26.0"

# --- Source unique de vérité -------------------------------------------------
NOEUDS = []
NOEUDS << { "nom" => "bdd1", "ip" => "#{RESEAU}.31", "mem" => 768, "role" => "bdd" }
NOEUDS << { "nom" => "bdd2", "ip" => "#{RESEAU}.32", "mem" => 768, "role" => "replique" }
(1..NB_APP).each do |i|
  NOEUDS << { "nom" => "app#{i}", "ip" => "#{RESEAU}.#{20 + i}", "mem" => 512, "role" => "app" }
end
NOEUDS << { "nom" => "lb1", "ip" => "#{RESEAU}.11", "mem" => 512, "role" => "lb" }
NOEUDS << { "nom" => "lb2", "ip" => "#{RESEAU}.12", "mem" => 512, "role" => "lb" }  if E1_LB2
NOEUDS << { "nom" => "obs", "ip" => "#{RESEAU}.41", "mem" => 768, "role" => "obs" } if E2_OBS

PLATEFORME = {
  "groupe"     => GROUPE,
  "prefixe"    => RESEAU,
  "reseau"     => "#{RESEAU}.0/24",
  "vip"        => VIP,
  "port_app"   => 3000,
  "port_bdd"   => 5432,
  "port_hote"  => PORT_HOTE,
  "extensions" => { "e1_lb2" => E1_LB2, "e2_obs" => E2_OBS },
  "noeuds"     => NOEUDS,
}

# Écriture seulement si le contenu change (pas de modification inutile).
def ecrire_si_change(chemin, contenu)
  return if File.exist?(chemin) && File.binread(chemin) == contenu
  File.binwrite(chemin, contenu)
end
FileUtils.mkdir_p(File.join(RACINE, "config"))
ecrire_si_change(File.join(RACINE, "config", "plateforme.json"), JSON.pretty_generate(PLATEFORME) + "\n")
ecrire_si_change(File.join(RACINE, "config", "noeuds.yml"), NOEUDS.to_yaml)

# Variables transmises aux scripts de provisionnement (jamais écrites dans le dépôt).
VARIABLES = DOTENV.merge(
  "GROUPE" => GROUPE.to_s,
  "NB_APP" => NB_APP.to_s,
  "E1_LB2" => E1_LB2 ? "1" : "0",
  "E2_OBS" => E2_OBS ? "1" : "0",
)

Vagrant.configure("2") do |config|
  config.vm.box              = BOITE
  config.vm.box_version      = VERSION
  config.vm.box_check_update = false

  # Les machines sont créées dans l'ordre de la table : bases, applications,
  # puis répartiteurs (qui découvrent les applications déjà présentes).
  NOEUDS.each do |n|
    config.vm.define n["nom"] do |m|
      m.vm.hostname = n["nom"]
      m.vm.network "private_network", ip: n["ip"]

      # R8 : seul le répartiteur expose un port vers l'hôte (en plus du SSH
      # de Vagrant), et uniquement sur 127.0.0.1.
      if n["nom"] == "lb1"
        m.vm.network "forwarded_port", id: "http", guest: 80, host: PORT_HOTE,
                     host_ip: "127.0.0.1", auto_correct: false
      end

      m.vm.provider "virtualbox" do |vb|
        vb.name         = "resultats-bf-g#{GROUPE}-#{n['nom']}"
        vb.memory       = n["mem"]
        vb.cpus         = 1
        vb.linked_clone = true
      end

      # Socle commun à toutes les machines (rejoué à chaque up : idempotent).
      m.vm.provision "commun", type: "shell", path: "scripts/commun.sh",
                     env: VARIABLES, run: "always"

      # Rôle de la machine. Le répartiteur est rejoué à chaque « vagrant up » :
      # c'est ce qui lui fait découvrir les nouveaux serveurs quand NB_APP change.
      m.vm.provision "role", type: "shell", path: "scripts/#{n['role']}.sh",
                     env: VARIABLES, run: (n["role"] == "lb" ? "always" : "once")
    end
  end
end
