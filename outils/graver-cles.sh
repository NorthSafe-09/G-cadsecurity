#!/usr/bin/env bash
# Grave l'ISO de G-CAD Security sur une ou plusieurs clés USB, puis vérifie chaque copie.
# Usage : sudo ./graver-cles.sh gcad.iso /dev/sdX [/dev/sdY ...]
# ATTENTION : tout le contenu des clés indiquées est effacé.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Lance ce script avec sudo." >&2
    exit 1
fi
if [[ $# -lt 2 ]]; then
    echo "Usage : sudo $0 gcad.iso /dev/sdX [/dev/sdY ...]" >&2
    echo
    echo "Clés USB détectées :"
    lsblk -d -o NAME,SIZE,TRAN,MODEL | awk 'NR==1 || /usb/'
    exit 1
fi

ISO="$1"; shift
[[ -f "$ISO" ]] || { echo "ISO introuvable : $ISO" >&2; exit 1; }

# Vérifie la somme de contrôle si le fichier .sha256 est à côté
if [[ -f "$ISO.sha256" ]]; then
    echo "Vérification de l'ISO…"
    (cd "$(dirname "$ISO")" && sha256sum -c "$(basename "$ISO").sha256")
fi

ISO_SIZE=$(stat -c %s "$ISO")
ROOT_DISK=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null || true)

for DEV in "$@"; do
    NAME=$(basename "$DEV")
    [[ -b "$DEV" ]] || { echo "$DEV n'est pas un périphérique." >&2; exit 1; }
    [[ "$NAME" != "$ROOT_DISK" ]] || { echo "$DEV est le disque système : refusé." >&2; exit 1; }
    [[ "$(lsblk -dno TRAN "$DEV")" == "usb" ]] || { echo "$DEV n'est pas une clé USB : refusé." >&2; exit 1; }
    DEV_SIZE=$(lsblk -bdno SIZE "$DEV")
    (( DEV_SIZE > ISO_SIZE )) || { echo "$DEV est trop petite pour l'ISO." >&2; exit 1; }
done

echo
lsblk -d -o NAME,SIZE,MODEL "$@"
echo
read -r -p "Tout effacer sur ces clés et y graver G-CAD Security ? Tape OUI : " REP
[[ "$REP" == "OUI" ]] || { echo "Annulé."; exit 0; }

for DEV in "$@"; do
    echo "== $DEV : gravure =="
    umount "${DEV}"?* 2>/dev/null || true
    dd if="$ISO" of="$DEV" bs=4M oflag=direct status=progress conv=fsync
    echo "== $DEV : vérification =="
    if cmp -n "$ISO_SIZE" "$ISO" "$DEV"; then
        echo "$DEV : OK"
    else
        echo "$DEV : ÉCHEC, copie différente de l'ISO" >&2
        exit 1
    fi
done

echo
echo "Toutes les clés sont prêtes."
