#!/usr/bin/env python3
"""Vorlesestimme mit Wortzeiten für Kapitel, Tafeln und Menus (edge-tts, WordBoundary).

Je Audiodatei: Content/Audio/<stem>.m4a (AAC 32 kbit/s mono) + <stem>.json
  {"voice", "duration" (ms), "segments": [{"seite", "block", "item", "text"}],
   "words": [{"s": Segment, "a","e": Zeichen in neu, "aa","ae": Zeichen in alt, "t": Start ms, "d": Dauer ms, "p": Satzende}]}
Content/Audio/index.json: {"kapitel": {slug: [{"stem", "seiten": [von, bis], "duration"}]}, "tafeln": {nr: stem}, "menus": {bild: stem}}

Gesprochener Text ≠ Anzeigetext: Abkürzungen und alte Schreibweisen werden nur für die Stimme ersetzt (AUSSPRACHE),
die Zuordnung läuft über Token (Anzeige-Token → gesprochene Wörter), daher sind Mehrwort-Ersetzungen erlaubt.
Kapitel werden an Seitengrenzen in Dateien von ≤ MAX_WOERTER Wörtern (~10 min) geteilt.

Aufruf: .venv/bin/python tools/build_audio.py [--voice de-AT-JonasNeural] [--only capitel-01] [--force] [--tafeln] [--menus]
Ohne --force werden nur fehlende oder inhaltlich veraltete Dateien vertont. Ausgaben werden im Repo gecacht.
"""
import argparse
import asyncio
import hashlib
import json
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

import edge_tts

HIER = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HIER)
from fraktur import frakturisieren  # noqa: E402

ROOT = os.path.dirname(HIER)
CONTENT = os.path.join(ROOT, 'Content', 'content.json')
OUT = os.path.join(ROOT, 'Content', 'Audio')
VOICES = {'de': 'de-AT-JonasNeural', 'fr': 'fr-FR-HenriNeural', 'en': 'en-US-GuyNeural'}
from audio_text import (MAX_WOERTER, SATZENDE, AUSSPRACHE, TOKEN, WORTZEICHEN,
                        gesprochen_tokens, segmente_kapitel, teile)


async def synth(text, voice):
    audio = bytearray(); bounds = []
    for versuch in range(3):
        audio = bytearray(); bounds = []
        comm = edge_tts.Communicate(text, voice, boundary='WordBoundary')
        async for chunk in comm.stream():
            if chunk['type'] == 'audio':
                audio.extend(chunk['data'])
            elif chunk['type'] == 'WordBoundary':
                bounds.append((chunk['offset'], chunk['duration'], chunk['text']))
        if audio and bounds:
            break
    return bytes(audio), bounds


def align(segs, bounds):
    """WordBoundary-Wörter im gesprochenen Text der Reihe nach suchen und auf Anzeige-Zeichen zurückführen."""
    # gesprochener Gesamttext: Segmente mit Absatzpausen verketten
    gesamt = []; tokmap = []  # tokmap: (gs_start, gs_end, seg_index, a_start, a_end, ist_wort)
    pos = 0
    for k, (si, bi, ii, text, nr) in enumerate(segs):
        for a, e, sp, ist_wort in gesprochen_tokens(text):
            gesamt.append(sp); tokmap.append((pos, pos + len(sp), k, a, e, ist_wort)); pos += len(sp)
        gesamt.append('\n\n'); pos += 2
    joined = ''.join(gesamt)
    words = []; cursor = 0; verloren = 0
    ti = 0
    for off, dur, w in bounds:
        w0 = w.strip().strip('.,;:!?„“"()»«…')
        if not w0:
            continue
        j = joined.find(w0, cursor)
        if j < 0 or j - cursor > 160:
            j2 = joined.lower().find(w0.lower(), cursor)
            if 0 <= j2 and j2 - cursor <= 160:
                j = j2
            else:
                verloren += 1; continue
        je = j + len(w0)
        # Anzeige-Token, die diesen gesprochenen Bereich überlappen (nur Wort-Token)
        while ti < len(tokmap) and tokmap[ti][1] <= j:
            ti += 1
        treffer = [t for t in tokmap[ti:ti + 6] if t[0] < je and t[1] > j and t[5]]
        if not treffer:
            cursor = je; verloren += 1; continue
        k = treffer[0][2]
        a = min(t[3] for t in treffer if t[2] == k); e = max(t[4] for t in treffer if t[2] == k)
        rest = joined[je:].lstrip('“"»«)')
        satz = bool(rest) and rest[0] in SATZENDE
        words.append({'s': k, 'a': a, 'e': e, 't': off // 10000, 'd': dur // 10000, 'p': satz})
        cursor = je
    return joined, words, verloren


def gesprochener_text(segs):
    return '\n\n'.join(''.join(sp for _, _, sp, _ in gesprochen_tokens(t)) for _, _, _, t, _ in segs)


def alt_bereiche(words, segs):
    maps = {}
    for w in words:
        k = w['s']
        if k not in maps:
            maps[k] = frakturisieren(segs[k][3]).map
        mp = maps[k]
        w['aa'] = mp[w['a']]; w['ae'] = mp[w['e']]
    return words


def transcode(mp3, m4a):
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', mp3, '-c:a', 'aac', '-b:a', '32k', '-ac', '1', m4a], check=True)
    out = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', m4a],
                         capture_output=True, text=True).stdout.strip()
    return int(float(out) * 1000)


def hash_von(text, voice):
    return hashlib.sha1((voice + '\n' + text).encode('utf-8')).hexdigest()[:16]


def vertonen(stem, segs, voice, force=False):
    js = os.path.join(OUT, stem + '.json'); m4a = os.path.join(OUT, stem + '.m4a'); mp3 = os.path.join(OUT, stem + '.mp3')
    text = gesprochener_text(segs)
    h = hash_von(text, voice)
    segments = [{'seite': si, 'block': bi, 'item': ii, 'text': t, 'nr': nr} for si, bi, ii, t, nr in segs]
    if not force and os.path.exists(js) and os.path.exists(m4a):
        alt = json.load(open(js, encoding='utf-8'))
        # Gleiche Aussprache kann andere Zeichenbereiche haben (z. B. Local → Lokal).
        if alt.get('hash') == h and alt.get('segments') == segments:
            return alt, False
    audio, bounds = asyncio.run(synth(text, voice))
    if not audio or not bounds:
        raise RuntimeError(f'{stem}: keine Audiodaten/WordBoundaries')
    open(mp3, 'wb').write(audio)
    dauer = transcode(mp3, m4a)
    os.remove(mp3)
    joined, words, verloren = align(segs, bounds)
    words = alt_bereiche(words, segs)
    daten = {'voice': voice, 'duration': dauer, 'hash': h, 'verloren': verloren,
             'segments': segments,
             'words': words}
    json.dump(daten, open(js, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    letztes = words[-1]['t'] + words[-1]['d'] if words else 0
    print(f'{stem}: {len(words)} Wörter, {dauer / 60000:.1f} min, verloren {verloren}, erstes Wort {words[0]["t"] if words else "-"} ms, '
          f'Ende-Abstand {dauer - letztes} ms, {os.path.getsize(m4a) // 1024} KB')
    return daten, True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--voice', default=VOICES['de'])
    ap.add_argument('--only', default=None)
    ap.add_argument('--force', action='store_true')
    ap.add_argument('--tafeln', action='store_true')
    ap.add_argument('--menus', action='store_true')
    ap.add_argument('--kapitel', action='store_true')
    ap.add_argument('--jobs', type=int, choices=range(1, 5), default=1,
                    help='Parallele Kapitelteile (1–4); Index wird anschließend zentral geschrieben')
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    alles = not (a.tafeln or a.menus or a.kapitel)
    lib = json.load(open(CONTENT, encoding='utf-8'))
    ipfad = os.path.join(OUT, 'index.json')
    index = json.load(open(ipfad, encoding='utf-8')) if os.path.exists(ipfad) else {'kapitel': {}, 'tafeln': {}, 'menus': {}}
    if alles or a.kapitel:
        jobs = []
        for k in lib['kapitel']:
            if a.only and a.only != k['slug']:
                continue
            segs = segmente_kapitel(k)
            for n, stueck in enumerate(teile(segs), 1):
                stem = f"{k['slug']}-{n}"
                jobs.append((k['slug'], stem, stueck))

        def kapitelteil(job):
            slug, stem, stueck = job
            daten, _ = vertonen(stem, stueck, a.voice, a.force)
            return slug, {'stem': stem, 'seiten': [stueck[0][4], stueck[-1][4]], 'duration': daten['duration']}

        aktualisiert = {}
        with ThreadPoolExecutor(max_workers=a.jobs) as pool:
            for slug, eintrag in pool.map(kapitelteil, jobs):
                aktualisiert.setdefault(slug, []).append(eintrag)
        index['kapitel'].update(aktualisiert)
        json.dump(index, open(ipfad, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    if alles or a.tafeln:
        for g in lib['tafeln']:
            for t in g['tafeln']:
                if a.only and a.only != f"tafel-{t['nr']}":
                    continue
                segs = [(0, -1, -1, f"Tafel {t['nr']}. {t['titel']}", t['seite'])]
                segs += [(0, i, -1, b['de_neu'], t['seite']) for i, b in enumerate(t['beschriftungen']) if b.get('de_neu')]
                stem = f"tafel-{t['nr']}"
                vertonen(stem, segs, a.voice, a.force)
                index['tafeln'][t['nr']] = stem
        json.dump(index, open(ipfad, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    if alles or a.menus:
        for g in lib['menus']:
            for k in g['karten']:
                sprache = k.get('sprache', 'de')
                voice = a.voice if sprache == 'de' else VOICES.get(sprache, a.voice)
                segs = [(0, i, -1, z['neu'], '') for i, z in enumerate(k['zeilen'])]
                if not segs:
                    continue
                stem = 'menu-' + os.path.splitext(k['bild'])[0]
                vertonen(stem, segs, voice, a.force)
                index['menus'][k['bild']] = stem
        json.dump(index, open(ipfad, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    gesamt = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT) if f.endswith('.m4a'))
    print(f'Audio gesamt: {gesamt / 1e6:.1f} MB')


if __name__ == '__main__':
    main()
