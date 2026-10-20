#!/usr/bin/env python3
"""Régénère en français les libellés Touch ID de la Touch Bar (t1bridge).

Les libellés sont des masques alpha précalculés dans
crates/t1-touchbar/src/overlay_labels.rs (Inter Medium 4.1). Taille étalonnée
sur les originaux : 26 px (écart moyen ~6/255, simple anticrénelage).

Prérequis Debian : apt install fonts-inter python3-pil
Usage : python3 gen-labels-fr.py ~/t1/t1bridge/crates/t1-touchbar/src/overlay_labels.rs
        puis : cargo build --locked --release -p t1-touchbar --bin t1-touchbar
"""
import re
import sys

from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/opentype/inter/Inter-Medium.otf"
SIZE = 26
FR = {
    "ENROLLMENT": "Posez et levez le doigt sur Touch ID plusieurs fois",
    "AUTHENTICATE": "Déverrouiller avec Touch ID",
    "APPROVE": "Autoriser avec Touch ID",
    "RETRY": "Réessayez",
    "SUCCESS": "Déverrouillé",
}


def render(text):
    font = ImageFont.truetype(FONT, SIZE)
    left, top, right, bottom = font.getbbox(text)
    im = Image.new("L", (right - left + 4, bottom - top + 4), 0)
    ImageDraw.Draw(im).text((2 - left, 2 - top), text, font=font, fill=255)
    return im.crop(im.getbbox())


def rust_array(data):
    lines, line = [], "   "
    for value in (str(v) for v in data):
        if len(line) + len(value) + 2 > 99:
            lines.append(line)
            line = "   "
        line += " " + value + ","
    lines.append(line)
    return "\n".join(lines)


def main(path):
    src = open(path, encoding="utf-8").read()
    for name, text in FR.items():
        im = render(text)
        width, height = im.size
        arr = rust_array(im.tobytes())
        src, n_pixels = re.subn(
            r"(const %s_PIXELS: &\[u8\] = &\[\n).*?(\n\];)" % name,
            lambda m: m.group(1) + arr + m.group(2),
            src,
            flags=re.S,
        )
        src, n_size = re.subn(
            r"(const %s: AlphaMask = AlphaMask \{\s*width: )\d+(,\s*height: )\d+" % name,
            lambda m: f"{m.group(1)}{width}{m.group(2)}{height}",
            src,
        )
        if n_pixels != 1 or n_size != 1:
            sys.exit(f"{name} : libellé introuvable dans {path}")
        print(f"{name:13} {width}x{height}  {text}")
    open(path, "w", encoding="utf-8").write(src)


if __name__ == "__main__":
    main(sys.argv[1])
