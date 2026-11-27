#!/usr/bin/env bash
# G-CAD Security : préparation de l'initramfs de la clé USB (session d'essai).
# Repris des ISO officielles de secureblue (prep_initramfs.sh), plus le lecteur DVD virtuel.
set -euo pipefail

ldconfig
# secureblue bloque squashfs (système live) et cdrom/sr_mod (lecteur DVD de VirtualBox)
sed -i -E '/^install (squashfs|cdrom|sr_mod) /d' /usr/lib/modprobe.d/secureblue.conf
printf 'install %s /sbin/modprobe --ignore-install %s\n' squashfs squashfs cdrom cdrom sr_mod sr_mod > /etc/modprobe.d/zz-squashfs-override.conf
echo 'install_items+=" /usr/lib64/libno_rlimit_as.so /etc/ld.so.cache /etc/modprobe.d/zz-squashfs-override.conf "' > /etc/dracut.conf.d/libs.conf

# Noyau Fedora pour la session d'essai (signé Secure Boot, compatible VirtualBox).
# Le système installé garde le noyau renforcé de secureblue.
dnf remove kernel-core -y
rm -rf /usr/lib/modules/*
dnf install --repo updates kernel kernel-modules-extra virtualbox-guest-additions -y
