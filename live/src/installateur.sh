#!/usr/bin/env bash
# Installe et configure Anaconda pour qu'il installe G-CAD Security sur le disque.
# Adapté de l'exemple Bazzite de Titanoboa (https://github.com/ublue-os/titanoboa, Apache-2.0).
set -exo pipefail

: "${IMAGE_REF:?IMAGE_REF doit être défini}"
IMAGE_NAME="${IMAGE_REF%:*}"
IMAGE_TAG="${IMAGE_REF##*:}"

source /etc/os-release

dnf install -qy --allowerasing anaconda-live libblockdev-{btrfs,lvm,dm}
mkdir -p /var/lib/rpm-state

# Corrections de la session live, reprises des ISO officielles de secureblue
dnf reinstall -y polkit                                   # secureblue retire pkexec
sed -i '/^UMASK[[:blank:]]/s/027/022/' /etc/login.defs
if [[ -L /mnt ]]; then rm -f /mnt && mkdir -m 0755 /mnt; fi # Anaconda a besoin de /mnt/sysroot
# L'installateur doit pouvoir lire l'image embarquée (session live seulement ;
# le système installé garde sa politique de signature stricte).
mkdir -p /etc/containers
jq '.transports["containers-storage"][""]=[{"type":"insecureAcceptAnything"}]' \
    /usr/share/containers/policy.json > /etc/containers/policy.json

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

echo "G-CAD Security" >/etc/system-release

# Kickstart : installe l'image embarquée dans la clé (hors ligne),
# puis fait pointer les mises à jour vers l'image signée en ligne.
mkdir -p /usr/share/anaconda/post-scripts
cat >>/usr/share/anaconda/interactive-defaults.ks <<EOF

ostreecontainer --url=${IMAGE_REF} --transport=containers-storage --no-signature-verification
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
    run0 --user=liveuser yad --on-top --timeout=0 --button="OK:0" \
        --title="Chiffrement obligatoire" \
        --text="<b>G-CAD Security doit être installé sur un disque chiffré.</b>\n\nL'installation a été arrêtée avant la copie du système. Ferme l'installateur, relance-le,\net à l'étape du disque coche « Chiffrer mes données »\navec une phrase de passe solide." || true
    exit 1
fi
%end
EOF

cat >/usr/share/anaconda/post-scripts/mises-a-jour-signees.ks <<EOF
%post --erroronfail --log=/tmp/gcad-mises-a-jour.log
# Après installation, n'accepte que les mises à jour signées par la clé de G-CAD Security.
sed -i 's|container-image-reference=.*|container-image-reference=ostree-image-signed:docker://${IMAGE_NAME}:${IMAGE_TAG}|' /ostree/deploy/default/deploy/*.origin
%end
EOF

# Désactive en live les services inutiles ou gênants (ignorés s'ils n'existent pas)
for s in \
    rpm-ostreed-automatic.timer \
    rpm-ostree-countme.service \
    bootloader-update.service; do
    systemctl disable "$s" || :
done
