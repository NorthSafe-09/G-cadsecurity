#!/usr/bin/env bash
# G-CAD Security : préparation de la session d'essai et de l'installateur.
# Inspiré des ISO officielles de secureblue (prep_rootfs.sh).
set -euo pipefail

IMAGE_REF="ghcr.io/northsafe-09/gcad"
IMAGE_TAG="latest"
source /etc/os-release

dnf reinstall -y polkit                       # secureblue retire pkexec
dnf install -y --allowerasing anaconda-live libblockdev-btrfs libblockdev-lvm libblockdev-dm jq
mkdir -p /var/lib/rpm-state
if [[ -L /mnt ]]; then rm -f /mnt && mkdir -m 0755 /mnt; fi
sed -i '/^UMASK[[:blank:]]/s/027/022/' /etc/login.defs

# Pas d'installations ni de mises à jour en arrière-plan dans la session d'essai
for u in secureblue-flatpak-setup.service secureblue-flatpak-setup.timer secureblue-bazaar-setup.timer podman-auto-update.timer gcad-ia-alpaca.service; do
    systemctl disable --global "$u" 2>/dev/null || :
done
for u in rpm-ostreed-automatic.timer rpm-ostree-countme.service rpm-ostree-countme.timer bootloader-update.service; do
    systemctl disable "$u" 2>/dev/null || :
done

# L'installateur doit pouvoir lire l'image embarquée (session d'essai seulement :
# le système installé garde sa politique de signature stricte).
mkdir -p /etc/containers
jq '.transports["containers-storage"][""]=[{"type":"insecureAcceptAnything"}]' \
    /usr/share/containers/policy.json > /etc/containers/policy.json

# Pas de mise en veille pendant l'essai ou l'installation
cat > /usr/share/glib-2.0/schemas/zz3-gcad-live-power.gschema.override <<'FIN'
[org.gnome.settings-daemon.plugins.power]
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-type='nothing'
sleep-inactive-ac-timeout=0
sleep-inactive-battery-timeout=0

[org.gnome.desktop.session]
idle-delay=uint32 0
FIN
glib-compile-schemas /usr/share/glib-2.0/schemas

# Profil Anaconda : partitionnement Btrfs, pas d'écran réseau ni mot de passe root
mkdir -p /etc/anaconda/profile.d
cat >/etc/anaconda/profile.d/gcad.conf <<EOF
[Profile]
profile_id = gcad

[Profile Detection]
os_id = ${ID}

[Network]
default_on_boot = FIRST_WIRED_WITH_LINK

[Bootloader]
efi_dir = fedora
menu_auto_hide = True

[Storage]
default_scheme = BTRFS
btrfs_compression = zstd:1

[User Interface]
hidden_spokes =
    NetworkSpoke
    PasswordSpoke

hidden_webui_pages =
    root-password
    network

[Localization]
use_geolocation = False
EOF

echo "GCAD OS" >/etc/system-release
# Nom du système partout (fenêtre d'accueil de l'installateur incluse)
for osr in /usr/lib/os-release /etc/os-release; do
    [[ -f "$osr" ]] || continue
    sed -i 's/^NAME=.*/NAME="GCAD OS"/;s/^PRETTY_NAME=.*/PRETTY_NAME="GCAD OS"/' "$osr"
done

# Kickstart : installe l'image embarquée dans la clé (hors ligne),
# puis fait pointer les mises à jour vers l'image signée en ligne.
mkdir -p /usr/share/anaconda/post-scripts
cat >>/usr/share/anaconda/interactive-defaults.ks <<EOF

ostreecontainer --url=${IMAGE_REF}:${IMAGE_TAG} --transport=containers-storage --no-signature-verification
%include /usr/share/anaconda/post-scripts/chiffrement-obligatoire.ks
%include /usr/share/anaconda/post-scripts/mises-a-jour-signees.ks
EOF

# Chiffrement du disque obligatoire : si l'utilisateur n'a pas coché
# « Chiffrer mes données », l'installation s'arrête AVANT d'écrire le système
# et un message lui explique quoi faire.
dnf install -qy --setopt=install_weak_deps=0 yad
cat >/usr/share/anaconda/post-scripts/chiffrement-obligatoire.ks <<'EOF'
%pre-install --erroronfail --log=/tmp/gcad-chiffrement.log
set -x
racine=$(findmnt -no SOURCE --nofsroot /mnt/sysroot)
if [[ -z "$racine" ]] || ! lsblk -s -no TYPE "$racine" | grep -qx crypt; then
    run0 --user=liveuser --setenv=WAYLAND_DISPLAY=wayland-0 --setenv=XDG_RUNTIME_DIR=/run/user/1000 yad --on-top --timeout=0 --button="OK:0" \
        --title="Chiffrement obligatoire" \
        --text="<b>G-CAD Security doit être installé sur un disque chiffré.</b>\n\nL'installation a été arrêtée avant la copie du système. Ferme l'installateur, relance-le,\net à l'étape du disque coche « Chiffrer mes données »\navec une phrase de passe solide." || true
    exit 1
fi
%end
EOF


# Après installation : mises à jour uniquement depuis l'image signée par G-CAD Security
cat >/usr/share/anaconda/post-scripts/mises-a-jour-signees.ks <<FIN
%post --erroronfail --log=/tmp/gcad-mises-a-jour.log
bootc switch --mutate-in-place --enforce-container-sigpolicy --transport registry ${IMAGE_REF}:${IMAGE_TAG}
%end
FIN
