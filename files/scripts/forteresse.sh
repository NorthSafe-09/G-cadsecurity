#!/usr/bin/env bash
# Installe la « forteresse » G-CAD dans l'image :
#  code de contrainte et compteur d'essais (PAM), contrôle des ports USB,
#  coupe-circuit VPN, Fake Travel, Centre G-CAD.
# Tout est DÉSACTIVÉ par défaut et en mode TEST : le propriétaire active chaque
# fonction dans le Centre G-CAD, l'essaie, puis arme la forteresse.
set -euo pipefail

chmod 0755 /usr/libexec/gcad/* /usr/bin/gcad-centre /usr/bin/gcad-fake-travel
chmod 0644 /usr/libexec/gcad/commun.sh

# Réglages par défaut (tout désactivé, mode test)
install -d -m 755 /etc/gcad
cat > /etc/gcad/reglages.conf <<'EOF'
MODE=simulation
CONTRAINTE_ACTIF=0
MAX_ESSAIS=0
PORTS_ACTIF=0
DELAI_PORT=60
ESSAIS_PORT=3
KILLSWITCH=0
LAN_AUTORISE=0
EOF
chmod 644 /etc/gcad/reglages.conf

# PAM : le gardien voit chaque mot de passe tapé APRÈS la vérification normale.
# Il ne change jamais le résultat de la connexion (module « optional »).
LIGNE='auth        optional      pam_exec.so expose_authtok quiet /usr/libexec/gcad/pam-garde'
ajouter_pam() {  # ajouter_pam <fichier> <motif de la ligne après laquelle insérer>
    local f="$1" motif="$2"
    # Fedora récent range les fichiers PAM par défaut dans /usr/lib/pam.d ;
    # une copie dans /etc/pam.d les remplace (règle standard de PAM).
    if [[ ! -f "$f" && -f "/usr/lib/pam.d/$(basename "$f")" ]]; then
        cp "/usr/lib/pam.d/$(basename "$f")" "$f"
    fi
    if [[ ! -f "$f" ]]; then
        echo "ERREUR : $f introuvable (ni dans /usr/lib/pam.d)" >&2
        exit 1
    fi
    grep -qF 'gcad/pam-garde' "$f" && return 0
    if ! grep -qE "$motif" "$f"; then
        echo "ERREUR : structure PAM inattendue dans $f (motif : $motif)" >&2
        exit 1
    fi
    awk -v motif="$motif" -v ligne="$LIGNE" '{print} !fait && $0 ~ motif {print ligne; fait=1}' "$f" > "$f.gcad"
    cat "$f.gcad" > "$f"; rm -f "$f.gcad"
}
ajouter_pam /etc/pam.d/gdm-password '^auth[[:space:]]+substack[[:space:]]+password-auth'
ajouter_pam /etc/pam.d/login        '^auth[[:space:]]+(substack|include)[[:space:]]+system-auth'

# Coupe-circuit VPN : le service est toujours actif, il ne bloque que si KILLSWITCH=1
systemctl enable gcad-killswitch.service
