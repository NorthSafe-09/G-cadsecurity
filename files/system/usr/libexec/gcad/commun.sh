#!/usr/bin/env bash
# Fonctions communes de la forteresse G-CAD Security.
# Réglages : /etc/gcad/reglages.conf (modifiés via le Centre G-CAD).

GCAD_ETC=/etc/gcad
GCAD_VAR=/var/lib/gcad
GCAD_LOG=/var/log/gcad.log

# Valeurs par défaut : TOUT est désactivé tant que le propriétaire n'a rien réglé.
MODE=simulation          # simulation | arme
CONTRAINTE_ACTIF=0       # code de contrainte (efface si tapé)
MAX_ESSAIS=0             # 0 = désactivé ; sinon effacement après N mauvais mots de passe
PORTS_ACTIF=0            # contrôle des ports USB
DELAI_PORT=60            # secondes pour taper le code ou débrancher
ESSAIS_PORT=3            # mauvais codes acceptés avant effacement
KILLSWITCH=0             # pas d'Internet sans VPN
LAN_AUTORISE=0           # réseau local permis même sans VPN (imprimante…)

[[ -r "$GCAD_ETC/reglages.conf" ]] && source "$GCAD_ETC/reglages.conf"

journal() {
    mkdir -p "$(dirname "$GCAD_LOG")"
    printf '%s  %s\n' "$(date '+%F %T')" "$*" >> "$GCAD_LOG"
    logger -t gcad -- "$*" 2>/dev/null || true
}

# Empreinte d'un code (SHA-512 salé, format crypt)
empreinte() { printf '%s' "$1" | openssl passwd -6 -stdin; }

# verifier_code <code> <fichier d'empreinte>
verifier_code() {
    local code="$1" fichier="$2" ref sel
    [[ -r "$fichier" ]] || return 1
    ref="$(head -1 "$fichier")"
    sel="$(cut -d'$' -f3 <<<"$ref")"
    [[ -n "$sel" ]] || return 1
    [[ "$(printf '%s' "$code" | openssl passwd -6 -salt "$sel" -stdin)" == "$ref" ]]
}

# Session graphique active : affiche "uid utilisateur"
session_active() {
    local id uid user
    while read -r id uid user _; do
        [[ -n "$id" ]] || continue
        if [[ "$(loginctl show-session "$id" -p Active --value 2>/dev/null)" == yes ]] &&
           [[ "$(loginctl show-session "$id" -p Type --value 2>/dev/null)" =~ ^(wayland|x11)$ ]] &&
           [[ "$(loginctl show-session "$id" -p Class --value 2>/dev/null)" == user ]]; then
            echo "$uid $user"; return 0
        fi
    done < <(loginctl list-sessions --no-legend 2>/dev/null)
    return 1
}

# en_session <uid> <utilisateur> <commande…> : lance une fenêtre dans la session de l'utilisateur
en_session() {
    local uid="$1" user="$2"; shift 2
    runuser -u "$user" -- env \
        XDG_RUNTIME_DIR="/run/user/$uid" \
        WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        "$@"
}

prevenir() {
    local s; s="$(session_active)" || return 0
    # shellcheck disable=SC2086
    en_session $s notify-send -u critical -i gcad "G-CAD Security" "$1" 2>/dev/null || true
}
