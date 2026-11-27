#!/usr/bin/bash
# Prépare l'environnement live de la clé USB.
# Adapté de l'exemple Bazzite de Titanoboa (https://github.com/ublue-os/titanoboa, Apache-2.0).
set -exo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${IMAGE_REF:?IMAGE_REF doit être défini (ex. ghcr.io/pseudo/gcad:latest)}"

mkdir -p "$(realpath /root)"
mount -o remount,rw /proc/sys || :

# 1. Embarque l'image complète de G-CAD Security dans la clé,
#    pour que l'installation marche sans Internet.
# Copie depuis le stockage de l'hôte (monté par le workflow) : pas de
# téléchargement, et pas de refus par la politique de signature de secureblue.
command -v skopeo >/dev/null || dnf install -y skopeo
skopeo --insecure-policy copy \
    "containers-storage:[overlay@/usr/lib/containers/storage]$IMAGE_REF" \
    "containers-storage:$IMAGE_REF"

# 2. Initramfs capable de démarrer en mode live
# secureblue bloque le module squashfs, indispensable au démarrage live
# (même méthode que les ISO officielles de secureblue).
ldconfig
sed -i '/^install squashfs /d' /usr/lib/modprobe.d/secureblue.conf
echo 'install squashfs /sbin/modprobe --ignore-install squashfs' > /etc/modprobe.d/zz-squashfs-override.conf
echo 'install_items+=" /usr/lib64/libno_rlimit_as.so /etc/ld.so.cache /etc/modprobe.d/zz-squashfs-override.conf "' > /etc/dracut.conf.d/libs.conf
dnf install -y dracut-live
kernel=$(kernel-install list --json pretty | jq -r '.[] | select(.has_kernel == true) | .version')
DRACUT_NO_XATTR=1 dracut -v --force --zstd --reproducible --no-hostonly \
    --add "dmsquash-live dmsquash-live-autooverlay" \
    "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

# Pas d'installations en arrière-plan dans la session d'essai
systemctl disable --global secureblue-flatpak-setup.service secureblue-flatpak-setup.timer secureblue-bazaar-setup.timer gcad-ia-alpaca.service 2>/dev/null || true
systemctl disable rpm-ostreed-automatic.timer 2>/dev/null || true

# 3. Session live GNOME
dnf install -y livesys-scripts
sed -i "s/^livesys_session=.*/livesys_session=gnome/" /etc/sysconfig/livesys
systemctl enable livesys.service livesys-late.service

# 4. Installateur Anaconda et configuration de l'installation
"$SCRIPT_DIR/installateur.sh"

# 5. Fichiers EFI attendus par le générateur d'ISO
dnf install -y grub2-efi-x64-cdboot xorriso isomd5sum
mkdir -p /boot/efi
cp -av /usr/lib/efi/*/*/EFI /boot/efi/

# 6. Fuseau UTC pour la session live
rm -f /etc/localtime
systemd-firstboot --timezone UTC

# 7. /var/tmp plus grand en live (ostree en a besoin pendant l'installation)
rm -rf /var/tmp || :
mkdir -p /var/tmp
cat >/etc/systemd/system/var-tmp.mount <<'EOF'
[Unit]
Description=Larger tmpfs for /var/tmp on live system

[Mount]
What=tmpfs
Where=/var/tmp
Type=tmpfs
Options=size=50%%,nr_inodes=1m

[Install]
WantedBy=local-fs.target
EOF
systemctl enable var-tmp.mount

# 8. Configuration du menu de démarrage de la clé
mkdir -p /usr/lib/bootc-image-builder
cp "$SCRIPT_DIR/iso.yaml" /usr/lib/bootc-image-builder/iso.yaml

dnf clean all
