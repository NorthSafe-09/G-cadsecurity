#!/usr/bin/env bash
# Image de marque G-CAD Security : nom, logo, fond d'écran, écran de mot de passe au démarrage.
# On ne change PAS la variable ID d'os-release : les outils de secureblue
# et de Fedora s'en servent pour fonctionner.
set -euo pipefail

OS_NAME="GCAD OS"

OS_RELEASE=/usr/lib/os-release
sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${OS_NAME}\"/" "$OS_RELEASE"
sed -i "s/^NAME=.*/NAME=\"${OS_NAME}\"/" "$OS_RELEASE"
for cle in VARIANT LOGO; do sed -i "/^${cle}=/d" "$OS_RELEASE"; done
cat >> "$OS_RELEASE" <<EOF
VARIANT="${OS_NAME}"
LOGO=gcad
EOF

# Message de bienvenue dans le terminal
cat > /etc/motd <<EOF

  ${OS_NAME}
  Guide : /usr/share/gcad/BIENVENUE.txt   ·   Réglages : Centre G-CAD

EOF

# Fond d'écran et écran de verrouillage par défaut
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/50-gcad <<'EOF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/gcad/gcad-fond.jpg'
picture-uri-dark='file:///usr/share/backgrounds/gcad/gcad-fond.jpg'
picture-options='zoom'
primary-color='#000000'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/gcad/gcad-fond.jpg'
picture-options='zoom'
primary-color='#000000'
EOF
if [[ ! -f /etc/dconf/profile/user ]]; then
    mkdir -p /etc/dconf/profile
    printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
fi
dconf update || true

# Écran de démarrage : l'affiche G-CAD avec la demande du mot de passe du disque.
# Le thème doit être inclus dans l'initramfs, qu'on régénère donc ici.
plymouth-set-default-theme gcad
KVER="$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | head -1)"
# Même appel que secureblue (ostree indispensable au démarrage, hardened_malloc),
# avec en plus le thème plymouth.
shopt -s nullglob
EXTRA=(/usr/lib64/libhardened_malloc.so /usr/lib64/glibc-hwcaps/*/libhardened_malloc.so)
shopt -u nullglob
DRACUT_NO_XATTR=1 dracut --kver "$KVER" --force \
    --add 'ostree plymouth' \
    --install "${EXTRA[*]}" \
    --remove '/usr/lib/systemd/system.conf.d/40-hardened_malloc.conf' \
    --no-hostonly --reproducible \
    "/usr/lib/modules/${KVER}/initramfs.img"
chmod 0600 "/usr/lib/modules/${KVER}/initramfs.img"
