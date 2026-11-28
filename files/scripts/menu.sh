#!/usr/bin/env bash
# Interface façon Windows : barre des tâches en bas (Dash to Panel) +
# menu Démarrer avec catégories (ArcMenu). Extensions installées par paquet
# système : secureblue ne bloque que les extensions ajoutées par l'utilisateur.
set -euo pipefail
cat > /etc/dconf/db/local.d/60-gcad-menu <<'FIN'
[org/gnome/shell]
enabled-extensions=['dash-to-panel@jderose9.github.com', 'arcmenu@arcmenu.com', 'places-menu@gnome-shell-extensions.gcampax.github.com']
favorite-apps=['gcad-centre.desktop', 'gcad-bac-a-sable.desktop', 'gcad-anonyme.desktop', 'gcad-claude.desktop', 'org.gnome.Boxes.desktop', 'io.github.kolunmi.Bazaar.desktop', 'trivalent.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Ptyxis.desktop', 'org.gnome.Settings.desktop']

[org/gnome/desktop/interface]
enable-animations=false

[org/gnome/desktop/search-providers]
disable-external=true

[org/gnome/shell/extensions/dash-to-panel]
panel-positions='{"0":"BOTTOM"}'
panel-element-positions='{"0":[{"element":"showAppsButton","visible":false,"position":"stackedTL"},{"element":"activitiesButton","visible":false,"position":"stackedTL"},{"element":"leftBox","visible":true,"position":"stackedTL"},{"element":"taskbar","visible":true,"position":"stackedTL"},{"element":"centerBox","visible":true,"position":"centerMonitor"},{"element":"rightBox","visible":true,"position":"stackedBR"},{"element":"dateMenu","visible":true,"position":"stackedBR"},{"element":"systemMenu","visible":true,"position":"stackedBR"},{"element":"desktopButton","visible":true,"position":"stackedBR"}]}'
appicon-margin=0
dot-position='BOTTOM'

[org/gnome/shell/extensions/arcmenu]
menu-layout='Windows'
distro-icon=0
menu-button-icon='Distro_Icon'
custom-menu-button-icon='file:///usr/share/pixmaps/gcad-logo.png'
menu-button-icon-size=28
FIN
dconf update || true

# Ollama tourne en service local (aucune donnée ne quitte le PC)
systemctl enable ollama.service 2>/dev/null || true
# Alpaca s'installe tout seul à la première connexion de chaque utilisateur
systemctl --global enable gcad-ia-alpaca.service || true

# Le mode anonyme (Tor global) démarre à la demande depuis l'app ; on crée juste l'utilisateur système
systemd-sysusers /usr/lib/sysusers.d/gcad-tor.conf || true
