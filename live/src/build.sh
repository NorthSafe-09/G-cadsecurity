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
podman pull "$IMAGE_REF"

# 2. Initramfs capable de démarrer en mode live
dnf install -y dracut-live
kernel=$(kernel-install list --json pretty | jq -r '.[] | select(.has_kernel == true) | .version')
DRACUT_NO_XATTR=1 dracut -v --force --zstd --reproducible --no-hostonly \
    --add "dmsquash-live dmsquash-live-autooverlay" \
    "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

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
