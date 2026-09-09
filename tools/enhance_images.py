#!/usr/bin/env python3
"""Restaurierung der Buch-Scans (Holzstiche auf gelbem Tonpapier, Handy-Scans) in nativer Auflösung.

Schritte je Bild:
  1. Seite freistellen + entzerren (größte helle Fläche → 4-Punkt-Perspektive), leichte Schräglage korrigieren
  2. Beleuchtungsausgleich: L-Kanal / geglätteter Hintergrund (Division), Papier wird gleichmäßig hell
  3. Durchschein der Rückseite: Levels-Kurve (Schwarz-/Weißpunkt, Gamma) + Sauvola-Schutzmaske außerhalb der Tusche
  4. Entrauschen (Non-local means) vor der Kurve
  5. Papierton: „warm“ (gedämpftes Original-Gelb) oder „neutral“ (Weiß)
  6. Export: Längsseite 2000 px (INTER_AREA), Unsharp, JPEG q85 progressiv; Thumb 480 px; Original 1200 px

Aufruf: .venv/bin/python tools/enhance_images.py [--only tafel_10] [--ton warm|neutral] [--out DIR] [--dewarp]
Kennzahlen je Bild landen in tools/review_site/out/bilder.json (für die Prüfseite).
"""
import argparse
import json
import os
import sys

import cv2
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, 'raw')
OUT = os.path.join(ROOT, 'Content')
REVIEW = os.path.join(ROOT, 'tools', 'review_site', 'out')

PAPIER_WARM = (0xF6, 0xEE, 0xDC)   # RGB, Theme-Papierton der App
PAPIER_NEUTRAL = (0xFB, 0xF9, 0xF4)


def bilder():
    for sub in ('plates', 'menus', 'details'):
        d = os.path.join(RAW, sub)
        for f in sorted(os.listdir(d)):
            if f.lower().endswith('.jpg'):
                yield sub, f
    for f in ('Servierkunde_1899_Einband.jpg', 'Servierkunde_1899_Titelblatt.jpg'):
        yield 'buch', f


def seite_freistellen(img):
    """Papierfläche finden (hell gegen dunklen Rand) und perspektivisch geraderücken. Fallback: unverändert."""
    h, w = img.shape[:2]
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (0, 0), 3)
    # Papier ist der große helle Bereich; Otsu trennt gegen den dunkleren Buchrand/Hintergrund
    _, th = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    th = cv2.morphologyEx(th, cv2.MORPH_CLOSE, np.ones((25, 25), np.uint8))
    cnts, _ = cv2.findContours(th, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not cnts:
        return img, 'kein-kontur'
    c = max(cnts, key=cv2.contourArea)
    if cv2.contourArea(c) < 0.5 * h * w:
        return img, 'flaeche-klein'
    rect = cv2.minAreaRect(c)
    box = cv2.boxPoints(rect)
    # Ecken ordnen: oben-links, oben-rechts, unten-rechts, unten-links
    s = box.sum(axis=1); d = np.diff(box, axis=1).ravel()
    tl, br = box[np.argmin(s)], box[np.argmax(s)]
    tr, bl = box[np.argmin(d)], box[np.argmax(d)]
    quelle = np.array([tl, tr, br, bl], dtype=np.float32)
    bw = int(max(np.linalg.norm(tr - tl), np.linalg.norm(br - bl)))
    bh = int(max(np.linalg.norm(bl - tl), np.linalg.norm(br - tr)))
    if bw < 0.6 * w or bh < 0.6 * h:
        return img, 'box-klein'
    ziel = np.array([[0, 0], [bw - 1, 0], [bw - 1, bh - 1], [0, bh - 1]], dtype=np.float32)
    M = cv2.getPerspectiveTransform(quelle, ziel)
    out = cv2.warpPerspective(img, M, (bw, bh), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)
    # schmalen Rand abschneiden (Buchkante, Schatten)
    m = int(0.012 * max(bw, bh))
    return out[m:bh - m, m:bw - m], f'entzerrt {bw}x{bh} winkel {rect[2]:.1f}'


def beleuchtung_ausgleichen(gray):
    bg = cv2.medianBlur(gray, 51)
    bg = cv2.GaussianBlur(bg, (0, 0), 15)
    norm = cv2.divide(gray, bg, scale=255)
    return np.clip(norm, 0, 255).astype(np.uint8)


def kurve(gray, schwarz=0.35, weiss=0.88, gamma=1.15):
    x = np.arange(256) / 255.0
    y = np.clip((x - schwarz) / (weiss - schwarz), 0, 1) ** gamma
    lut = (y * 255).astype(np.uint8)
    return cv2.LUT(gray, lut)


def sauvola_maske(gray, fenster=35, k=0.25):
    from skimage.filters import threshold_sauvola
    t = threshold_sauvola(gray, window_size=fenster, k=k)
    tusche = (gray < t).astype(np.uint8) * 255
    tusche = cv2.dilate(tusche, np.ones((5, 5), np.uint8))
    return tusche


def sanft(img):
    """Einband: kein Tinte-auf-Papier-Motiv. Nur Rand, Entrauschen, leichter Kontrast; Farben und Patina bleiben."""
    h, w = img.shape[:2]
    m = int(0.006 * max(h, w))
    img = img[m:h - m, m:w - m]
    img = cv2.fastNlMeansDenoisingColored(img, None, h=3, hColor=3, templateWindowSize=7, searchWindowSize=21)
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    clahe = cv2.createCLAHE(clipLimit=1.6, tileGridSize=(8, 8))
    lab[:, :, 0] = clahe.apply(lab[:, :, 0])
    return cv2.cvtColor(lab, cv2.COLOR_LAB2BGR), {'durchschein': [0, 0], 'modus': 'sanft'}


def restaurieren(img, ton='warm', dewarp=False):
    """Farberhaltende Restaurierung: Hintergrund-Division je Kanal (Papier → Weiß, Tinte behält Farbe: Rot bleibt Rot),
    Levels-Kurve + Sauvola-Schutzmaske auf der Helligkeit (Durchschein → Weiß), danach Papierton multiplikativ."""
    info = {}
    if dewarp:
        img, info['entzerrung'] = seite_freistellen(img)
    else:
        h, w = img.shape[:2]
        m = int(0.008 * max(h, w))            # Buchkante/Schatten am Rand knapp abschneiden
        img = img[m:h - m, m:w - m]
    img = cv2.fastNlMeansDenoisingColored(img, None, h=4, hColor=4, templateWindowSize=7, searchWindowSize=21)
    flach = np.zeros_like(img)
    for ch in range(3):
        flach[:, :, ch] = beleuchtung_ausgleichen(img[:, :, ch])
    lab = cv2.cvtColor(flach, cv2.COLOR_BGR2LAB)
    L = lab[:, :, 0]
    durchschein_vorher = float(((L > 150) & (L < 225)).mean())
    kurv = kurve(L)
    maske = sauvola_maske(L)
    hell = cv2.addWeighted(kurv, 0.25, np.full_like(kurv, 255), 0.75, 0)
    L2 = np.where(maske > 0, kurv, hell).astype(np.uint8)
    durchschein_nachher = float(((L2 > 150) & (L2 < 225)).mean())
    info['durchschein'] = [round(durchschein_vorher, 4), round(durchschein_nachher, 4)]
    # Farbe nur auf der Tinte behalten, Papier neutral
    a = lab[:, :, 1].astype(np.int16) - 128
    b = lab[:, :, 2].astype(np.int16) - 128
    gewicht = np.clip((255 - L2.astype(np.float32)) / 120.0, 0, 1)   # 0 auf Papier, 1 auf dunkler Tinte
    lab2 = np.stack([L2, np.clip(a * gewicht + 128, 0, 255).astype(np.uint8),
                     np.clip(b * gewicht + 128, 0, 255).astype(np.uint8)], axis=2)
    bgr = cv2.cvtColor(lab2, cv2.COLOR_LAB2BGR).astype(np.float32)
    papier = PAPIER_WARM if ton == 'warm' else PAPIER_NEUTRAL
    tint = np.array([papier[2], papier[1], papier[0]], np.float32) / 255.0   # RGB → BGR
    bgr = np.clip(bgr * tint, 0, 255).astype(np.uint8)
    info['farbanteil'] = round(float((np.abs(a) + np.abs(b))[maske > 0].mean()) if (maske > 0).any() else 0.0, 2)
    return bgr, info


def skalieren(img, laengsseite):
    h, w = img.shape[:2]
    f = laengsseite / max(h, w)
    if f >= 1:
        return img
    out = cv2.resize(img, (int(w * f), int(h * f)), interpolation=cv2.INTER_AREA)
    blur = cv2.GaussianBlur(out, (0, 0), 1.0)
    return cv2.addWeighted(out, 1.6, blur, -0.6, 0)


def speichern(img, pfad, q=85):
    os.makedirs(os.path.dirname(pfad), exist_ok=True)
    cv2.imwrite(pfad, img, [cv2.IMWRITE_JPEG_QUALITY, q, cv2.IMWRITE_JPEG_PROGRESSIVE, 1])
    return os.path.getsize(pfad)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--only', default=None)
    ap.add_argument('--ton', default='warm', choices=['warm', 'neutral'])
    ap.add_argument('--out', default=OUT)
    ap.add_argument('--dewarp', action='store_true', help='perspektivische Entzerrung (Scans sind bereits rektifiziert; kann Inhalt abschneiden)')
    ap.add_argument('--laengsseite', type=int, default=2000)
    a = ap.parse_args()
    os.makedirs(REVIEW, exist_ok=True)
    bericht = []
    for sub, f in bilder():
        if a.only and a.only not in f:
            continue
        quelle = os.path.join(RAW, sub, f) if sub != 'buch' else os.path.join(RAW, f)
        img = cv2.imread(quelle)
        if img is None:
            print('nicht lesbar', quelle); continue
        dewarp = a.dewarp and sub in ('plates', 'menus')
        if 'Einband' in f:
            res, info = sanft(img)
        else:
            res, info = restaurieren(img, a.ton, dewarp)
        name = os.path.splitext(f)[0] + '.jpg'
        gro = speichern(skalieren(res, a.laengsseite), os.path.join(a.out, 'Images', name))
        th = speichern(skalieren(res, 480), os.path.join(a.out, 'Thumbs', name), 80)
        orig = speichern(skalieren(img, 1200), os.path.join(a.out, 'Originals', name), 82)
        eintrag = {'file': name, 'gruppe': sub, 'quelle': [img.shape[1], img.shape[0]],
                   'ergebnis': [res.shape[1], res.shape[0]], 'bytes': [gro, th, orig], **info}
        bericht.append(eintrag)
        print(f"{name}: {info.get('entzerrung', '-')} | durchschein {info['durchschein']} | {gro // 1024} KB")
    pfad = os.path.join(REVIEW, 'bilder.json')
    alt = []
    if os.path.exists(pfad) and a.only:
        alt = [e for e in json.load(open(pfad)) if e['file'] not in {b['file'] for b in bericht}]
    json.dump(alt + bericht, open(pfad, 'w'), ensure_ascii=False, indent=1)
    gesamt = sum(b['bytes'][0] for b in alt + bericht)
    print(f'{len(alt + bericht)} Bilder, Images gesamt {gesamt / 1e6:.1f} MB')


if __name__ == '__main__':
    main()
