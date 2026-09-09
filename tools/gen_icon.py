#!/usr/bin/env python3
"""App-Icon 1024×1024 „Herr Ober!“: goldene Servierglocke (Cloche) auf Flaschengrün, darunter Fraktur-Schriftzug.
Echtes gezeichnetes Motiv (PIL), keine Text-in-PNG-Abkürzung. Ausgabe: Sources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
und 120-px-Version für die IOSAPPS-Übersicht (tools/review_site/out/icon-120.png)."""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 1024
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'Sources', 'Assets.xcassets', 'AppIcon.appiconset', 'icon-1024.png')
KLEIN = os.path.join(ROOT, 'tools', 'review_site', 'out', 'icon-120.png')
FRAKTUR = os.path.join(ROOT, 'Fonts', 'UnifrakturMaguntia-Book.ttf')
os.makedirs(os.path.dirname(OUT), exist_ok=True)
os.makedirs(os.path.dirname(KLEIN), exist_ok=True)

GRUEN_H, GRUEN_D = (0x36, 0x6B, 0x51), (0x22, 0x47, 0x36)
GOLD, GOLD_D, GOLD_H = (0xC9, 0xA4, 0x4E), (0x9A, 0x78, 0x2E), (0xEE, 0xD5, 0x8A)
PAPIER = (0xF6, 0xEE, 0xDC)

# Hintergrund: radialer Verlauf Flaschengrün
img = Image.new('RGB', (S, S), GRUEN_D)
px = img.load()
for y in range(S):
    for x in range(S):
        d = math.hypot(x - S * 0.5, y - S * 0.42) / (S * 0.75)
        t = min(1.0, d)
        px[x, y] = tuple(round(GRUEN_H[i] + (GRUEN_D[i] - GRUEN_H[i]) * t) for i in range(3))

# Schatten unter der Glocke
shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.ellipse((200, 640, 824, 720), fill=(0, 0, 0, 110))
shadow = shadow.filter(ImageFilter.GaussianBlur(30))
img.paste(shadow, (0, 0), shadow)

draw = ImageDraw.Draw(img, 'RGBA')
cx = S // 2
# Cloche: Halbkugel mit Lichtkante
top, base_y, r = 250, 640, 300
draw.pieslice((cx - r, top, cx + r, top + 2 * r), 180, 360, fill=GOLD)
# Lichtreflex links oben
hl = Image.new('RGBA', (S, S), (0, 0, 0, 0))
hd = ImageDraw.Draw(hl)
hd.pieslice((cx - r + 40, top + 40, cx + r - 120, top + 2 * r - 120), 200, 300, fill=(*GOLD_H, 120))
hl = hl.filter(ImageFilter.GaussianBlur(24))
img.paste(hl, (0, 0), hl)
draw = ImageDraw.Draw(img, 'RGBA')
# dunkler Rand unten an der Kuppel
draw.arc((cx - r, top, cx + r, top + 2 * r), 180, 360, fill=GOLD_D, width=14)
# Sockelleiste (Rand der Glocke)
draw.rounded_rectangle((cx - r - 40, base_y - 30, cx + r + 40, base_y + 26), radius=28, fill=GOLD)
draw.rounded_rectangle((cx - r - 40, base_y + 2, cx + r + 40, base_y + 26), radius=12, fill=GOLD_D)
# Tablett darunter
draw.rounded_rectangle((cx - r - 110, base_y + 58, cx + r + 110, base_y + 96), radius=19, fill=GOLD)
draw.rounded_rectangle((cx - r - 110, base_y + 80, cx + r + 110, base_y + 96), radius=8, fill=GOLD_D)
# Knauf
draw.ellipse((cx - 44, top - 60, cx + 44, top + 28), fill=GOLD)
draw.ellipse((cx - 26, top - 46, cx + 4, top - 16), fill=(*GOLD_H, 170))
draw.rounded_rectangle((cx - 16, top + 10, cx + 16, top + 40), radius=8, fill=GOLD_D)

# Schriftzug „Herr Ober!“ in Fraktur auf Papierton
try:
    font = ImageFont.truetype(FRAKTUR, 150)
except OSError:
    font = ImageFont.load_default()
text = 'Herr Ober!'
bbox = draw.textbbox((0, 0), text, font=font)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
tx, ty = cx - tw // 2 - bbox[0], 770 - bbox[1]
draw.text((tx + 4, ty + 6), text, font=font, fill=(0, 0, 0, 90))
draw.text((tx, ty), text, font=font, fill=PAPIER)

img.save(OUT, 'PNG')
img.resize((120, 120), Image.LANCZOS).save(KLEIN, 'PNG')
print('Icon:', OUT, img.size, '→', KLEIN)
