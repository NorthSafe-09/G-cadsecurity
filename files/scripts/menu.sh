#!/usr/bin/env bash
# Menu « Applications » en haut à gauche (style Parrot OS) + menu « Emplacements ».
# Extensions GNOME officielles installées par paquet système : secureblue bloque
# seulement l'installation d'extensions par l'utilisateur, pas celles-ci.
set -euo pipefail
cat > /etc/dconf/db/local.d/60-gcad-menu <<'FIN'
[org/gnome/shell]
enabled-extensions=['apps-menu@gnome-shell-extensions.gcampax.github.com', 'places-menu@gnome-shell-extensions.gcampax.github.com']
favorite-apps=['gcad-centre.desktop', 'io.github.kolunmi.Bazaar.desktop', 'trivalent.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Ptyxis.desktop', 'gcad-fake-travel.desktop', 'org.gnome.Settings.desktop']
FIN
dconf update || true

# Ollama tourne en service local (aucune donnée ne quitte le PC)
systemctl enable ollama.service 2>/dev/null || true
# Alpaca s'installe tout seul à la première connexion de chaque utilisateur
systemctl --global enable gcad-ia-alpaca.service || true
