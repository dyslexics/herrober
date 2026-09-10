#!/usr/bin/env python3
"""Prüfseiten für Mario: Text (roh | neu | Fraktur), Tafeln/Menus (vorher | nachher, Beschriftungen), Hörproben,
ſ-Wortliste und offene Stellen. Statische HTML-Dateien, Ziel: /var/www/html/HERROBER/review/ (Basic-Auth wie HERROBER).

Aufruf: .venv/bin/python tools/review_site/build_review.py [--deploy]
"""
import argparse
import glob
import html
import json
import os
import re
import shutil
import subprocess
import sys
from collections import Counter

HIER = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HIER)
ROOT = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from build_content import seiten_parsen, KAPITEL, abschnitt_datei, RAWK  # noqa: E402
from fraktur import frakturisieren  # noqa: E402

OUT = os.path.join(HIER, 'out', 'site')
DEPLOY = '/var/www/html/HERROBER/review'
CONTENT = json.load(open(os.path.join(ROOT, 'Content', 'content.json'), encoding='utf-8'))

CSS = """
:root{--papier:#f6eedc;--tinte:#2b2118;--gruen:#2f5d46;--gold:#b08d3c;--mark:#ffe500;--linie:#d9cdb2}
*{box-sizing:border-box}body{margin:0;font:16px/1.5 -apple-system,system-ui,Segoe UI,Roboto,sans-serif;color:var(--tinte);background:#fbf8f1}
header{background:var(--gruen);color:#fff;padding:14px 24px}header a{color:#f3e7c4;margin-right:18px;text-decoration:none;font-weight:600}
main{max-width:1500px;margin:0 auto;padding:20px 24px}h1{font-size:22px;margin:0}h2{margin:28px 0 8px;font-size:20px;color:var(--gruen)}
.seite{border-top:2px solid var(--linie);margin-top:26px;padding-top:10px}.seite h3{margin:0 0 10px;font-size:15px;color:#7a6a4a}
.dreispaltig{display:grid;grid-template-columns:1fr 1fr 1fr;gap:18px}.dreispaltig>div{min-width:0}
.roh{font-family:ui-monospace,Menlo,monospace;font-size:13px;color:#5a4d3a;white-space:pre-wrap;background:#fff;padding:10px;border-radius:8px}
.neu{font-family:'Atkinson Hyperlegible',system-ui,sans-serif;font-size:17px;background:#fff;padding:10px 14px;border-radius:8px}
.alt{font-family:'UnifrakturMaguntia',serif;font-size:21px;line-height:1.45;background:var(--papier);padding:10px 14px;border-radius:8px}
.alt .antiqua{font-family:'Atkinson Hyperlegible',system-ui,sans-serif;font-size:17px}
.randtitel{font-weight:700;color:var(--gruen);font-size:.95em;margin:12px 0 4px}.ueberschrift{font-weight:700;font-size:1.15em;margin:10px 0}
.fussnote{font-size:.85em;color:#5a4d3a;margin-top:8px}.unsicher{background:#ffd8d8;padding:0 3px;border-radius:3px}
p{margin:0 0 10px}table{border-collapse:collapse;font-size:14px}td,th{border:1px solid var(--linie);padding:3px 8px;vertical-align:top}
.karten{display:grid;grid-template-columns:repeat(auto-fill,minmax(420px,1fr));gap:22px}.karte{background:#fff;border-radius:10px;padding:12px;box-shadow:0 1px 4px #0002}
.vergleich{position:relative;width:100%;aspect-ratio:var(--ar,0.65);overflow:hidden;border-radius:8px;background:#ddd}
.vergleich img{position:absolute;inset:0;width:100%;height:100%;object-fit:contain}
.vergleich .nach{clip-path:inset(0 0 0 var(--x,50%))}.vergleich input{position:absolute;inset:auto 0 8px 0;width:100%;z-index:2;margin:0}
.vergleich .label{position:absolute;top:6px;padding:2px 8px;background:#0008;color:#fff;font-size:12px;border-radius:4px}
.beschr{font-size:14px;margin-top:8px}.beschr .fr{color:#6b5a3a}.beschr .alt{display:inline;padding:0 4px;font-size:18px}
audio{width:100%}.hinweis{background:#fff7d6;border-left:4px solid var(--gold);padding:10px 14px;border-radius:6px}
.kennzahl{font-size:12px;color:#7a6a4a}.woerter{columns:4;font-size:14px}.woerter div{break-inside:avoid}
.stat td{font-size:14px}
"""


def esc(s):
    return html.escape(s or '')


def alt_html(block_alt, antiqua):
    """Fraktur-Text mit Antiqua-Bereichen als <span class=antiqua>."""
    if not antiqua:
        return esc(block_alt)
    out, pos = [], 0
    for a, e in antiqua:
        out.append(esc(block_alt[pos:a])); out.append(f'<span class="antiqua">{esc(block_alt[a:e])}</span>'); pos = e
    out.append(esc(block_alt[pos:]))
    return ''.join(out)


def block_html(b, schrift):
    t = b['typ']
    if t == 'liste':
        tag = 'ol' if b.get('nummeriert') else 'ul'
        items = ''.join(f'<li>{alt_html(i["alt"], i.get("antiqua")) if schrift == "alt" else esc(i["neu"])}</li>' for i in b['items'])
        return f'<{tag}>{items}</{tag}>'
    if t == 'tabelle':
        rows = ''.join('<tr>' + ''.join(f'<td>{esc(c)}</td>' for c in z) + '</tr>' for z in b['zeilen'])
        return f'<table>{rows}</table>'
    text = alt_html(b['alt'], b.get('antiqua')) if schrift == 'alt' else esc(b['neu'])
    return f'<p class="{t}">{text}</p>'


def seite_html(kapitel_slug, seite, roh_text):
    neu = ''.join(block_html(b, 'neu') for b in seite['bloecke'])
    alt = ''.join(block_html(b, 'alt') for b in seite['bloecke'])
    return f'''<div class="seite" id="s{esc(seite['nr'])}"><h3>Seite {esc(seite['nr'])} {esc(seite.get('titel', ''))}</h3>
<div class="dreispaltig"><div><div class="kennzahl">OCR-Rohfassung</div><div class="roh">{esc(roh_text)}</div></div>
<div><div class="kennzahl">korrigiert · Antiqua (neu)</div><div class="neu">{neu}</div></div>
<div><div class="kennzahl">Fraktur (alt)</div><div class="alt">{alt}</div></div></div></div>'''


def roh_seiten(praefix):
    pfad = glob.glob(os.path.join(RAWK, praefix + '*.md'))[0]
    text = open(pfad, encoding='utf-8').read()
    out, aktuell, nr = {}, [], None
    for line in text.split('\n'):
        m = re.match(r'^### Seite (\S+)', line)
        if m:
            if nr: out[nr] = '\n'.join(aktuell).strip()
            nr, aktuell = m.group(1), []
        elif nr and not line.startswith(('<a id', '*Quelle:', '###')):
            aktuell.append(line)
    if nr: out[nr] = '\n'.join(aktuell).strip()
    return out


def kopf(titel, aktiv=''):
    nav = ''.join(f'<a href="{h}">{t}</a>' for h, t in [('index.html', 'Übersicht'), ('text.html', 'Text'), ('tafeln.html', 'Tafeln'),
                                                        ('menus.html', 'Menus'), ('woerter.html', 'ſ-Wörter'), ('offen.html', 'Offene Stellen')])
    return f'''<!doctype html><html lang="de"><head><meta charset="utf-8"><title>{esc(titel)} · Herr Ober! Prüfseite</title>
<meta name="viewport" content="width=device-width,initial-scale=1"><style>{CSS}
@font-face{{font-family:'UnifrakturMaguntia';src:url(fonts/UnifrakturMaguntia-Book.ttf)}}
@font-face{{font-family:'Atkinson Hyperlegible';src:url(fonts/AtkinsonHyperlegible-Regular.ttf)}}</style></head><body>
<header><a href="index.html"><strong>Herr Ober! · Servierkunde 1899</strong></a>{nav}</header><main>'''


FUSS = '</main></body></html>'


def text_seite():
    teile = [kopf('Text'), '<h1>Text: OCR-Rohfassung · korrigiert · Fraktur</h1><p class="hinweis">Links die OCR-Rohfassung, Mitte der korrigierte Text (so wird er vorgelesen), rechts die Fraktur-Ableitung mit langem ſ. Rot hinterlegt: unsichere Stellen. Bitte Stichproben am Buch prüfen.</p>']
    teile.append('<p>' + ' · '.join(f'<a href="#{k["slug"]}">{esc(k["nummer"] or k["titel"])}</a>' for k in CONTENT['kapitel']) + '</p>')
    for praefix, slug, nummer, titel in KAPITEL:
        k = next(k for k in CONTENT['kapitel'] if k['slug'] == slug)
        roh = roh_seiten(praefix)
        status = ' <span class="unsicher">noch Rohtext, Korrektur läuft</span>' if k.get('quelle_fallback') else ''
        teile.append(f'<h2 id="{slug}">{esc(nummer)} {esc(titel)}{status}</h2>')
        for s in k['seiten']:
            teile.append(seite_html(slug, s, roh.get(s['nr'], '')))
    teile.append(FUSS)
    return '\n'.join(teile)


def vergleich(name, ar):
    return f'''<div class="vergleich" style="--ar:{ar:.3f}"><img src="originals/{name}" alt=""><img class="nach" src="images/{name}" alt="">
<span class="label" style="left:8px">Original-Scan</span><span class="label" style="right:8px">Bereinigt</span>
<input type="range" min="0" max="100" value="50" oninput="this.parentNode.style.setProperty('--x',this.value+'%')"></div>'''


def tafeln_seite(kennzahlen):
    teile = [kopf('Tafeln'), '<h1>Bildtafeln: Original-Scan ↔ bereinigt, Beschriftungen</h1><p class="hinweis">Schieberegler ziehen. Die bereinigte Fassung ist die App-Version (Beleuchtung ausgeglichen, Durchschein entfernt, Papierton vereinheitlicht, Farben der Tinte erhalten). Darunter die aus dem Bild transkribierten Beschriftungen in Antiqua und Fraktur.</p>']
    for g in CONTENT['tafeln']:
        teile.append(f'<h2>{esc(g["titel"])}</h2><div class="karten">')
        for t in g['tafeln']:
            kz = kennzahlen.get(t['bild'], {})
            ar = (kz.get('ergebnis', [3, 4])[0] / max(1, kz.get('ergebnis', [3, 4])[1]))
            b = ''.join(f'<div><b>{"" if not x.get("nr") else x["nr"] + ". "}</b>{esc(x.get("de_neu", ""))} <span class="alt">{alt_html(x.get("de_alt", ""), x.get("antiqua"))}</span>'
                        f'{" <span class=fr>— " + esc(x["fr"]) + "</span>" if x.get("fr") else ""}</div>' for x in t['beschriftungen'])
            uns = f'<div class="unsicher">unsicher: {esc("; ".join(t["unsicher"]))}</div>' if t.get('unsicher') else ''
            det = f'<div class="kennzahl">Details: {", ".join(d["bild"] for d in t["details"])}</div>' if t['details'] else ''
            teile.append(f'<div class="karte"><b>Tafel {esc(t["nr"])}</b> · S. {esc(t["seite"])} · {esc(t["titel"])}{vergleich(t["bild"], ar)}'
                         f'<div class="kennzahl">{kz.get("bytes", [0])[0] // 1024} KB · Durchschein {kz.get("durchschein", ["", ""])[0]} → {kz.get("durchschein", ["", ""])[1]}</div>'
                         f'<div class="beschr">{b}</div>{uns}{det}</div>')
        teile.append('</div>')
    teile.append(FUSS)
    return '\n'.join(teile)


def menus_seite(kennzahlen):
    teile = [kopf('Menus'), '<h1>Menus und amerikanische Tischkarten</h1>']
    for g in CONTENT['menus']:
        teile.append(f'<h2>{esc(g["titel"])}</h2><div class="karten">')
        for k in g['karten']:
            kz = kennzahlen.get(k['bild'], {})
            ar = (kz.get('ergebnis', [3, 4])[0] / max(1, kz.get('ergebnis', [3, 4])[1]))
            z = ''.join(f'<div class="{esc(x["art"])}">{esc(x["neu"])}' + (f' <span class="alt">{alt_html(x["alt"], x.get("antiqua"))}</span>' if k.get('sprache') == 'de' else '') + '</div>' for x in k['zeilen'])
            uns = f'<div class="unsicher">unsicher: {esc("; ".join(k["unsicher"]))}</div>' if k.get('unsicher') else ''
            teile.append(f'<div class="karte"><b>{esc(k["titel"])}</b> · {esc(k.get("ort_datum", ""))} · {esc(k.get("sprache", ""))}{vergleich(k["bild"], ar)}<div class="beschr">{z}</div>{uns}</div>')
        teile.append('</div>')
    teile.append(FUSS)
    return '\n'.join(teile)


def woerter_seite():
    zaehler, formen = Counter(), {}
    for k in CONTENT['kapitel']:
        for s in k['seiten']:
            for b in s['bloecke']:
                texte = [i['neu'] for i in b['items']] if b['typ'] == 'liste' else ([b['neu']] if 'neu' in b else [])
                for t in texte:
                    r = frakturisieren(t)
                    for neu, alt in r.woerter:
                        zaehler[neu] += 1; formen[neu] = alt
    teile = [kopf('ſ-Wörter'), f'<h1>ſ-Entscheidungen: {len(zaehler)} verschiedene Wörter mit s</h1><p class="hinweis">Nach Häufigkeit. Prüfe vor allem die häufigen Wörter; Korrekturen kommen in tools/fraktur_ausnahmen.json.</p><div class="woerter">']
    for neu, n in zaehler.most_common():
        teile.append(f'<div>{n} × {esc(neu)} → <span class="alt" style="display:inline;padding:0 4px;font-size:18px">{esc(formen[neu])}</span></div>')
    teile.append('</div>' + FUSS)
    return '\n'.join(teile)


def offen_seite(status):
    teile = [kopf('Offene Stellen'), '<h1>Offene Stellen</h1>']
    if status.get('fallback'):
        teile.append(f'<p class="hinweis">Noch nicht korrigiert (Rohtext im Bundle): {esc(", ".join(status["fallback"]))}</p>')
    teile.append(f'<h2>{len(status.get("unsicher", []))} unsichere Wörter der Korrektur</h2><table class="stat"><tr><th>Wo</th><th>Wort</th><th>Umfeld</th></tr>')
    for u in status.get('unsicher', []):
        teile.append(f'<tr><td>{esc(u["wo"])}</td><td><b>{esc(u["wort"])}</b></td><td>{esc(u["umfeld"])}</td></tr>')
    teile.append('</table>')
    teile.append('<h2>Fehlendes Material</h2><ul><li>20 Quell-PDFs (Textseiten) aus Apple Notes → <code>/var/www/html/HERROBER/IDEE/sources/</code></li><li>21 Bilder der Beilage 1936 → <code>/var/www/html/HERROBER/IDEE/pictures/1936/</code></li></ul>')
    teile.append(FUSS)
    return '\n'.join(teile)


def index_seite(kennzahlen, status):
    kap = ''.join(f'<tr><td>{esc(k["nummer"])}</td><td>{esc(k["titel"])}</td><td>{len(k["seiten"])}</td><td>{k["woerter"]}</td><td>{"Rohtext" if k.get("quelle_fallback") else "korrigiert"}</td></tr>' for k in CONTENT['kapitel'])
    proben = ''.join(f'<div class="karte"><b>{v}</b><audio controls preload="none" src="audio/probe_{v}.mp3"></audio></div>'
                     for v in ('de-AT-JonasNeural', 'de-AT-IngridNeural', 'de-DE-ConradNeural'))
    probe_text = open(os.path.join(HIER, 'out', 'audio', 'probe_text.txt'), encoding='utf-8').read() if os.path.exists(os.path.join(HIER, 'out', 'audio', 'probe_text.txt')) else ''
    gesamt = sum(k.get('bytes', [0])[0] for k in kennzahlen.values())
    shot_dir = os.path.join(HIER, 'out', 'shots')
    shots = ''.join(f'<div class="karte"><img src="shots/{f}" style="width:100%;border-radius:8px" alt="{esc(f)}"><div class="kennzahl">{esc(f)}</div></div>'
                    for f in sorted(os.listdir(shot_dir)) if f.endswith('.png')) if os.path.isdir(shot_dir) else ''
    return f'''{kopf('Übersicht')}<h1>Herr Ober! – Servierkunde 1899 · Prüfseiten</h1>
<p class="hinweis">Stand wird bei jedem Build neu erzeugt. Entscheidungen bitte an Henry: Stimme, Bildvarianten, Korrekturen.</p>
<h2>Hörprobe: Welche Stimme?</h2><p>Text: „{esc(probe_text[:160])}…“</p><div class="karten">{proben}</div>
<h2>Text</h2><table class="stat"><tr><th>Nr.</th><th>Kapitel</th><th>Seiten</th><th>Wörter</th><th>Status</th></tr>{kap}</table>
<p>{len(status.get("unsicher", []))} unsichere Wörter → <a href="offen.html">Offene Stellen</a> · <a href="text.html">Text dreispaltig</a> · <a href="woerter.html">ſ-Wortliste</a></p>
<h2>Bilder</h2><p>{len(kennzahlen)} Bilder bereinigt, App-Fassung gesamt {gesamt / 1e6:.1f} MB → <a href="tafeln.html">Tafeln</a> · <a href="menus.html">Menus</a></p>
<h2>App-Screenshots (Simulator, aktueller Build)</h2><div class="karten">{shots}</div>
{FUSS}'''


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--deploy', action='store_true'); a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    kennz = {e['file']: e for e in json.load(open(os.path.join(HIER, 'out', 'bilder.json')))} if os.path.exists(os.path.join(HIER, 'out', 'bilder.json')) else {}
    status = json.load(open(os.path.join(HIER, 'out', 'text_status.json'), encoding='utf-8')) if os.path.exists(os.path.join(HIER, 'out', 'text_status.json')) else {}
    seiten = {'index.html': index_seite(kennz, status), 'text.html': text_seite(), 'tafeln.html': tafeln_seite(kennz),
              'menus.html': menus_seite(kennz), 'woerter.html': woerter_seite(), 'offen.html': offen_seite(status)}
    for name, inhalt in seiten.items():
        open(os.path.join(OUT, name), 'w', encoding='utf-8').write(inhalt)
    os.makedirs(os.path.join(OUT, 'fonts'), exist_ok=True)
    for f in ('UnifrakturMaguntia-Book.ttf', 'AtkinsonHyperlegible-Regular.ttf'):
        shutil.copy(os.path.join(ROOT, 'Fonts', f), os.path.join(OUT, 'fonts', f))
    for sub, ziel in (('Images', 'images'), ('Originals', 'originals')):
        d = os.path.join(OUT, ziel); os.makedirs(d, exist_ok=True)
        for f in os.listdir(os.path.join(ROOT, 'Content', sub)):
            shutil.copy(os.path.join(ROOT, 'Content', sub, f), os.path.join(d, f))
    for sub in ('audio', 'shots'):
        if os.path.isdir(os.path.join(HIER, 'out', sub)):
            shutil.copytree(os.path.join(HIER, 'out', sub), os.path.join(OUT, sub), dirs_exist_ok=True)
    print('Prüfseiten in', OUT, sorted(seiten))
    if a.deploy:
        os.makedirs(DEPLOY, exist_ok=True)
        subprocess.run(['rsync', '-a', '--delete', OUT + '/', DEPLOY + '/'], check=True)
        print('deployed →', DEPLOY)


if __name__ == '__main__':
    main()
