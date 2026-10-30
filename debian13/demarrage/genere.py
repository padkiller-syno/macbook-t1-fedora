#!/usr/bin/env python3
# Génère les images du thème Plymouth « pomme » à la taille de l'écran Retina (2880x1800).
# Le script du thème les met à l'échelle H/1800 de façon uniforme, pour garder les arrondis.
import os
import gi
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf

ICI = os.path.dirname(os.path.abspath(__file__))


def svg(nom, largeur, hauteur, corps):
    chemin = os.path.join(ICI, nom)
    src = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{largeur}" height="{hauteur}" '
           f'viewBox="0 0 {largeur} {hauteur}">{corps}</svg>')
    tmp = chemin + ".svg"
    with open(tmp, "w") as f:
        f.write(src)
    GdkPixbuf.Pixbuf.new_from_file_at_size(tmp, largeur, hauteur).savev(chemin, "png", [], [])
    os.remove(tmp)


# Pomme blanche, hauteur du logo du firmware Apple sur cet écran.
# Le logo (marque Apple) n'est pas dans le dépôt : récupéré sur Wikimedia Commons au premier lancement.
LOGO = os.path.join(ICI, "pomme.svg")
if not os.path.exists(LOGO):
    import urllib.request
    req = urllib.request.Request("https://upload.wikimedia.org/wikipedia/commons/f/fa/Apple_logo_black.svg",
                                 headers={"User-Agent": "Mozilla/5.0 (theme plymouth perso)"})
    with urllib.request.urlopen(req) as r, open(LOGO, "wb") as f:
        f.write(r.read())
with open(LOGO) as f:
    trace = f.read().split('d="', 1)[1].split('"', 1)[0]
svg("pomme.png", 85, 104, f'<g transform="scale({104 / 1000})"><path fill="#fff" d="{trace}"/></g>')

# Champ du mot de passe : pilule blanche translucide, texte d'invite gris
CW, CH = 400, 56
svg("champ.png", CW, CH,
    f'<rect width="{CW}" height="{CH}" rx="{CH / 2}" fill="#fff" fill-opacity="0.18"/>'
    f'<text x="26" y="{CH / 2 + 9}" font-family="Inter" font-size="26" fill="#fff" fill-opacity="0.55">'
    'Saisir le mot de passe</text>')
svg("champ-vide.png", CW, CH,
    f'<rect width="{CW}" height="{CH}" rx="{CH / 2}" fill="#fff" fill-opacity="0.18"/>')

# Point de saisie et bouton flèche (apparaît dès le premier caractère)
svg("point.png", 14, 14, '<circle cx="7" cy="7" r="7" fill="#fff"/>')
svg("fleche.png", 40, 40,
    '<circle cx="20" cy="20" r="19" fill="none" stroke="#fff" stroke-opacity="0.85" stroke-width="2.5"/>'
    '<path d="M12 20h15M21 13.5l6.5 6.5-6.5 6.5" fill="none" stroke="#fff" stroke-width="3" '
    'stroke-linecap="round" stroke-linejoin="round"/>')

# Barre de progression du démarrage : piste grise et remplissage blanc
BW, BH = 280, 8
svg("barre-piste.png", BW, BH, f'<rect width="{BW}" height="{BH}" rx="{BH / 2}" fill="#fff" fill-opacity="0.25"/>')
svg("barre-plein.png", BW, BH, f'<rect width="{BW}" height="{BH}" rx="{BH / 2}" fill="#fff"/>')
print("images générées dans", ICI)
