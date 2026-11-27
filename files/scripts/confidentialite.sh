#!/usr/bin/env bash
# Active par défaut, pour tous les utilisateurs, la suppression automatique
# des métadonnées des photos (comme l'appareil photo de GrapheneOS).
set -euo pipefail

chmod 0755 /usr/bin/gcad-exif-auto
chmod 0755 "/etc/skel/.local/share/nautilus/scripts/Nettoyer les métadonnées"
systemctl --global enable gcad-exif-auto.service
