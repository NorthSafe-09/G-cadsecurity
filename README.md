# G-CAD Security

Un système pour PC qui reprend la philosophie de GrapheneOS : durci par défaut, mises à jour
automatiques, signées et atomiques (avec retour arrière). Vendu sur une seule clé USB qui sert
à la fois à **essayer** le système sans rien toucher et à **l'installer**.

G-CAD Security est une image personnalisée de [secureblue](https://github.com/secureblue/secureblue)
(Fedora Atomic durci). Il hérite de : hardened_malloc (le même allocateur mémoire que GrapheneOS),
le navigateur Trivalent (Chromium durci), un noyau et des paramètres système renforcés, des
mises à jour signées et réversibles.

> G-CAD Security n'est affilié ni à GrapheneOS, ni à secureblue, ni au projet Fedora.

---

### Protections en plus de secureblue

- **Disque chiffré obligatoire** : l'installateur refuse d'installer G-CAD Security si la case
  « Chiffrer mes données » n'est pas cochée (`live/src/installateur.sh`).
- **Photos sans métadonnées** : comme l'appareil photo de GrapheneOS, toute image arrivant dans
  le dossier Images perd automatiquement ses métadonnées EXIF/XMP/IPTC (GPS, appareil, date…),
  sauf l'orientation, sans perte de qualité (`/usr/bin/gcad-exif-auto`, désactivable).
- **Nettoyage manuel** de tout autre fichier (PDF, documents, vidéo, audio) par clic droit,
  avec mat2.

### La forteresse (application « Centre G-CAD »)

Tout est **désactivé et en mode TEST** à la livraison : le client règle chaque fonction, l'essaie
(en TEST un message s'affiche, rien n'est effacé), puis arme la forteresse.

| Fonction | Ce qui se passe | Fichiers |
|---|---|---|
| Effacement | Détruit la clé de chiffrement de chaque disque LUKS puis coupe le courant : données illisibles pour toujours | `usr/libexec/gcad/effacer` |
| Code de contrainte | Ce faux mot de passe, tapé à la connexion ou au verrouillage, déclenche l'effacement | `pam-garde`, PAM `gdm-password` et `login` |
| Essais avant effacement | N mauvais mots de passe d'affilée = effacement | `pam-garde` |
| Contrôle des ports USB | Tout appareil inconnu est bloqué ; code des ports ou débranchement en 60 s, sinon effacement (3 mauvais codes = effacement) | `port-udev`, `port-garde`, règle udev |
| Pas d'Internet sans VPN | Pare-feu nftables : rien ne sort hors du tunnel VPN, pas de fuite DNS | `killswitch-appliquer` |
| Fake Travel | Fausse position (service de localisation GeoClue) et fuseau horaire de la ville choisie | `gcad-fake-travel` |
| Écran de mot de passe | L'affiche G-CAD au démarrage, avec la demande du mot de passe du disque | thème Plymouth `gcad` |

Limites à connaître :
- Le code de contrainte et le compteur d'essais protègent la **session** (connexion, verrouillage,
  console), pas le mot de passe du disque demandé au démarrage.
- Le contrôle des ports couvre l'USB (y compris USB-C). Un appareil de confiance est reconnu par
  son identifiant ; un appareil malveillant pourrait l'imiter.
- Fake Travel trompe les applications qui demandent la position au système. Les sites web
  voient surtout l'adresse IP : il faut le VPN dans le même pays.
- L'effacement est volontairement **irréversible** : rappelle aux clients de garder une sauvegarde.

### Qui fabrique les mises à jour de sécurité ?

Pas toi. Les correctifs viennent des équipes Fedora (qui suivent les failles publiées et
reprennent les correctifs des projets d'origine : noyau Linux, navigateurs, etc.) et de l'équipe
secureblue pour le durcissement. Ton dépôt GitHub reconstruit G-CAD Security chaque jour avec ces
correctifs, le signe, et les PC de tes clients l'installent automatiquement.

## Comment ça marche

```
GitHub (gratuit)                                   Toi                    Tes clients
┌────────────────────────────┐                ┌──────────────┐        ┌─────────────────┐
│ 1. Construit l'image G-CAD │  chaque jour   │              │        │ Démarrent sur   │
│    sur secureblue, signée  │──────────────▶ │              │        │ la clé : essai  │
│ 2. Fabrique l'ISO de la    │  à la demande  │ graves l'ISO │ ─────▶ │ puis installe   │
│    clé USB (live + install)│──────────────▶ │ sur les clés │        │ en quelques     │
└────────────────────────────┘                └──────────────┘        │ clics           │
          │                                                           └────────┬────────┘
          └──────────── mises à jour signées, téléchargées automatiquement ◀───┘
```

| Dossier | Rôle |
|---|---|
| `recipes/recipe.yml` | Recette de l'OS : base secureblue, personnalisations, signature |
| `files/` | Fichiers ajoutés au système et script de personnalisation |
| `live/` | Environnement de la clé USB : session d'essai + installateur Anaconda |
| `.github/workflows/build.yml` | Construction automatique de l'image et de l'ISO |
| `outils/graver-cles.sh` | Grave et vérifie l'ISO sur plusieurs clés d'un coup |

---

## Mise en route (une seule fois)

Dépôt : https://github.com/NorthSafe-09/G-cadsecurity · Image : `ghcr.io/northsafe-09/gcad`

1. **Clé de signature** : la clé publique `cosign.pub` est déjà dans le dépôt. Sa clé privée
   (`cosign.key`, jamais publiée) va dans *Settings → Secrets and variables → Actions →
   New repository secret*, nom `SIGNING_SECRET`. **Garde une copie de `cosign.key` en lieu sûr** :
   c'est elle qui garantit que seules TES mises à jour sont acceptées par les PC de tes clients.
2. **Construction** : chaque envoi sur `main` reconstruit l'image. Pour fabriquer aussi l'ISO :
   *Actions → gcad → Run workflow*, ou une étiquette `vX.Y` (par exemple `v1.0`).
   Compte environ 1 h à 1 h 30.
3. **Rends l'image publique** (une seule fois, après la 1re construction) : sur ton profil GitHub,
   *Packages → gcad → Package settings → Change visibility → Public*. Sans ça, les PC de tes
   clients ne pourront pas se mettre à jour.

Ensuite, l'image se reconstruit **chaque jour** avec les derniers correctifs de secureblue et
Fedora, et les PC installés les récupèrent tout seuls.

---

## Maintenance automatique

- **Chaque jour**, GitHub reconstruit l'image avec les derniers correctifs de secureblue et Fedora.
- **Chaque semaine**, le robot Dependabot (`.github/dependabot.yml`) propose une mise à jour si un
  outil de construction a une nouvelle version : il suffit d'accepter (« Merge ») la proposition.
- **Chaque semaine**, une tâche Claude programmée vérifie les changements de secureblue et de
  Titanoboa, et propose les corrections nécessaires au projet.

---

## Fabriquer les clés USB

1. *Actions → gcad → Run workflow*. À la fin, télécharge l'artefact **gcad-iso** (zip contenant
   `gcad.iso` et `gcad.iso.sha256`). Il reste disponible 7 jours.
2. Utilise des clés de **16 Go minimum** (l'ISO embarque tout le système pour installer sans Internet).
3. **Teste toujours l'ISO dans une machine virtuelle avant de graver un lot** (GNOME Boxes ou
   VirtualBox, en mode UEFI) : démarrage, session d'essai, installation, redémarrage, mise à jour.
4. Grave et vérifie plusieurs clés d'un coup (sur Linux) :
   ```bash
   sudo ./outils/graver-cles.sh gcad.iso /dev/sdb /dev/sdc /dev/sdd
   ```
   Sur Windows ou Mac, [Fedora Media Writer](https://fedoraproject.org/workstation/download)
   ou balenaEtcher marchent aussi, une clé à la fois.

Côté client : brancher la clé, démarrer dessus (touche F12, F2 ou Échap selon le PC), choisir
« Essayer ou installer G-CAD Security », puis cliquer sur « Installer » depuis la session d'essai.
**Conseille-leur de cocher le chiffrement du disque** dans l'installateur.

---

## Avant de vendre : points juridiques à vérifier

Je ne suis pas avocat ; fais valider ces points par un professionnel avant de commercialiser.

- **Vendre du logiciel libre est autorisé.** Les licences (GPL, Apache 2.0…) permettent de
  vendre des copies, mais tu dois fournir l'accès au code source. Ce dépôt GitHub public, plus les
  sources de Fedora et de secureblue, couvrent l'essentiel : indique ces liens sur l'emballage et
  sur ton site.
- **Garde les licences et mentions** de secureblue (Apache 2.0, fichier `LICENSE`) et de Titanoboa.
- **Marque Fedora.** Une distribution modifiée basée sur Fedora doit retirer les logos et la marque
  Fedora des endroits visibles (paquets `fedora-logos`, écran de démarrage, installateur), ou suivre
  les règles « Fedora Remix ». Ce projet ne le fait pas encore : c'est la prochaine étape avant la
  vente. Voir https://docs.fedoraproject.org/en-US/legal/trademarks/
- **Logo (personnage masqué).** Le masque de Guy Fawkes popularisé par « V pour Vendetta »
  est lié à des droits détenus par Warner Bros. Pour un logo commercial, fais vérifier ce point
  ou fais dessiner un personnage original. Les images sont dans `files/system/usr/share/`
  (`icons`, `pixmaps`, `backgrounds/gcad`, `plymouth/themes/gcad`) : il suffit de les remplacer.
- **Pas de « GrapheneOS ».** N'utilise pas le nom ni le logo de GrapheneOS (ni de secureblue) dans
  ta marque ou ta pub, et ne laisse pas entendre une affiliation. « Inspiré de… » ou « basé sur
  secureblue » en texte simple, de façon factuelle, reste plus sûr.
- **Promesses de sécurité.** Reste factuel (« durci », « mises à jour signées ») : aucun système
  n'est « inviolable », et les projets de sécurité eux-mêmes disent qu'un PC reste moins bien
  protégé qu'un Pixel sous GrapheneOS.
- **Ce que tu vends vraiment** : la clé prête à l'emploi, le support, l'installation, la marque.
  Pense aux obligations de vendeur (garantie légale, facture, statut d'entreprise).

---

## Limites à connaître

- Ce n'est pas un équivalent exact de GrapheneOS : le matériel PC n'offre pas les mêmes garanties
  qu'un Pixel (démarrage vérifié, puce de sécurité, isolement des applis).
- Les cartes NVIDIA demandent l'image `silverblue-nvidia-open-hardened` (voir `recipe.yml`) ;
  tu peux en faire une 2e recette et une 2e clé.
- Secure Boot : après installation, faire enregistrer la clé secureblue
  (`ujust enroll-secureblue-secure-boot-key`, expliqué dans le guide de bienvenue).
- Le générateur d'ISO (Titanoboa) est récent : s'il change, adapte `live/` d'après ses exemples
  (https://github.com/ublue-os/titanoboa).

## Crédits

secureblue (Apache 2.0) · BlueBuild · Universal Blue Titanoboa (Apache 2.0, dont `live/` est adapté) · Fedora Project.
