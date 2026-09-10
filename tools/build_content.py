#!/usr/bin/env python3
"""Baut Content/content.json aus der korrigierten Buchfassung.

Quellen:
  tools/korrektur/<NN>_<name>.md      korrigierte Abschnitte (Fallback: tools/korrektur/raw/, mit Warnung)
  tools/korrektur/tafeln/*.json       Tafelbeschriftungen (aus den Bildern transkribiert)
  tools/korrektur/menus/*.json        Menükarten
  raw/manifest.json                   Bild ↔ Seite, crop_fraction der Detailausschnitte
  tools/fibel.json, tools/ueber.md    Lernhilfe und Über-Text
  tools/warum.md                      Kapitel „Warum dieses Buch“ (DVLD, 2026)
  tools/fraktur.py                    neu → alt (ſ, ſs, ꝛc., Antiqua-Bereiche)

Blocktypen im Markdown der Korrektur: Absatz, `#### Überschrift`, `@@ Randtitel`, `*) Fußnote`, `- Liste`, `1. Liste`,
`| Tabelle |`, `> Zitat`, `![Bild](pfad)`. Unsichere Stellen `⟨Wort?⟩` werden entmarkt und gezählt.

Aufruf: .venv/bin/python tools/build_content.py [--check]
"""
import glob
import json
import os
import re
import sys
import unicodedata

import regex as uregex

HIER = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HIER)
from fraktur import frakturisieren  # noqa: E402
from rechtschreibung import modernisieren  # noqa: E402

ROOT = os.path.dirname(HIER)
KORR = os.path.join(HIER, 'korrektur')
RAWK = os.path.join(KORR, 'raw')
CONTENT = os.path.join(ROOT, 'Content')
IMAGES = os.path.join(CONTENT, 'Images')

KAPITEL = [  # (Dateipräfix, slug, Nummer-Label, Kurztitel)
    ('04_', 'einleitung', '', 'Einleitung'),
    ('05_', 'capitel-01', '1. Capitel', 'Über das Verhalten des Kellners im Dienste'),
    ('06_', 'capitel-02', '2. Capitel', 'Handhabung des Serviertuches und der Utensilien'),
    ('07_', 'capitel-03', '3. Capitel', 'Die Speisenfolge bei den Mahlzeiten'),
    ('08_', 'capitel-04', '4. Capitel', 'Die Speise-, Getränke- und die Tafelkarte'),
    ('09_', 'capitel-05', '5. Capitel', 'Über das Servieren der Getränke'),
    ('10_', 'capitel-06', '6. Capitel', 'Reinigung und Instandhaltung des Services'),
    ('11_', 'capitel-07', '7. Capitel', 'Das Tischdecken im allgemeinen'),
    ('12_', 'capitel-08', '8. Capitel', 'Das Servieren der einzelnen Mahlzeiten'),
    ('13_', 'capitel-09', '9. Capitel', 'Die Festtafel'),
    ('14_', 'capitel-10', '10. Capitel', 'Das Servieren in den Fremdenzimmern'),
    ('15_', 'couvertpreise', '', 'Einiges über die Ermittlung der Couvertpreise'),
]
TAFELGRUPPEN = [('16_', 'porzellan', 'Porzellan-Geschirr'), ('17_', 'glas', 'Glas-Geschirr'),
                ('18_', 'bestecke', 'Bestecke und Silbergeschirr'), ('19_', 'schemata', 'Schemata für Gedecke und Festtafeln')]

UNSICHER = re.compile(r'⟨([^⟨⟩]*?)\??⟩')
INLINE = [(re.compile(r'\*\*(.+?)\*\*'), r'\1'), (re.compile(r'(?<!\w)\*(?!\s)(.+?)(?<!\s)\*(?!\w)'), r'\1'),
          (re.compile(r'`([^`]+)`'), r'\1'), (re.compile(r'\[([^\]]+)\]\([^)]+\)'), r'\1')]
statistik = {'unsicher': 0, 'fallback': [], 'bloecke': 0, 'woerter': 0, 'unsicher_liste': [], 'kontext': ''}


def plain(s):
    def _merk(m):
        statistik['unsicher'] += 1
        statistik['unsicher_liste'].append({'wo': statistik['kontext'], 'wort': m.group(1), 'umfeld': s[max(0, m.start() - 40):m.end() + 40]})
        return m.group(1)
    s = UNSICHER.sub(_merk, s)
    for rx, ersatz in INLINE:
        s = rx.sub(ersatz, s)
    s = s.replace('&gt;', '>').replace('&lt;', '<').replace('&amp;', '&')
    s = unicodedata.normalize('NFC', s)
    return re.sub(r'[ \t]+', ' ', s).strip()


def grapheme_ok(s):
    return len(uregex.findall(r'\X', s)) == len(s) and not re.search('[​‌‍\r­]', s)


def textblock(typ, neu, modern=False, **extra):
    neu = plain(neu)
    if modern:
        neu = modernisieren(neu)
    if not neu:
        return None
    assert grapheme_ok(neu), f'Grapheme/Steuerzeichen in: {neu[:60]}'
    r = frakturisieren(neu)
    statistik['bloecke'] += 1
    statistik['woerter'] += len(re.findall(r'\w+', neu))
    b = {'typ': typ, 'neu': neu, 'alt': r.alt}
    if r.antiqua:
        b['antiqua'] = [list(x) for x in r.antiqua]
    b.update(extra)
    return b


def abschnitt_datei(praefix):
    k = glob.glob(os.path.join(KORR, praefix + '*.md'))
    if k:
        return k[0], False
    r = glob.glob(os.path.join(RAWK, praefix + '*.md'))
    statistik['fallback'].append(praefix)
    return r[0], True


def seiten_parsen(text, modern=False):
    """Abschnittstext → Liste von Seiten {nr, titel, bild, bloecke:[...]}."""
    seiten = []
    seite = None
    para, liste, tabelle, transkription = [], None, [], False

    def flush():
        nonlocal para, liste, tabelle
        if seite is None:
            para, liste, tabelle = [], None, []
            return
        if para:
            if not transkription:
                b = textblock('absatz', ' '.join(para), modern=modern)
                if b: seite['bloecke'].append(b)
            para = []
        if liste:
            items = [textblock('item', it, modern=modern) for it in liste['items']]
            items = [i for i in items if i]
            if items and not transkription:
                seite['bloecke'].append({'typ': 'liste', 'nummeriert': liste['nummeriert'], 'items': items})
            liste = None
        if tabelle:
            zeilen = [[modernisieren(plain(c)) if modern else plain(c) for c in row] for row in tabelle]
            if not transkription:
                seite['bloecke'].append({'typ': 'tabelle', 'zeilen': zeilen})
            tabelle = []

    for raw in text.split('\n'):
        line = raw.rstrip()
        s = line.strip()
        if s.startswith('### '):
            flush()
            t = s[4:].strip()
            m = re.match(r'^Seite (\d+(?:[–-]\d+)?)(?: · (.*))?$', t)
            seite = {'nr': m.group(1) if m else '', 'titel': (m.group(2) if m else t) or '', 'bloecke': []}
            if modern:
                seite['titel'] = modernisieren(seite['titel'])
            seiten.append(seite)
            statistik['kontext'] = f"Seite {seite['nr'] or seite['titel']}"
            transkription = False
            continue
        if seite is None:
            continue
        if not s:
            flush(); continue
        if s.startswith('<a id') or s.startswith('*Quelle:') or s.startswith('## '):
            flush(); continue
        if s.startswith('**Transkription der Beschriftungen'):
            flush(); transkription = True; continue
        if s.startswith('!['):
            flush()
            m = re.match(r'!\[([^\]]*)\]\(([^)]+)\)', s)
            if m:
                seite['bild'] = os.path.basename(m.group(2))
                seite.setdefault('bild_alt', m.group(1))
            continue
        if s.startswith('#'):
            flush()
            lvl = len(s) - len(s.lstrip('#'))
            b = textblock('ueberschrift', s[lvl:].strip(), modern=modern, ebene=lvl)
            if b and not transkription: seite['bloecke'].append(b)
            continue
        if s.startswith('@@'):
            flush()
            b = textblock('randtitel', s[2:].strip(), modern=modern)
            if b and not transkription: seite['bloecke'].append(b)
            continue
        if re.match(r'^\*{1,3}\)', s):
            flush()
            b = textblock('fussnote', s, modern=modern)
            if b and not transkription: seite['bloecke'].append(b)
            continue
        if s.startswith('>'):
            flush()
            b = textblock('zitat', s[1:].strip(), modern=modern)
            if b and not transkription: seite['bloecke'].append(b)
            continue
        if s.startswith('|'):
            if para or liste: flush()
            cells = [c.strip() for c in s.strip('|').split('|')]
            if all(c and set(c) <= set('-: ') for c in cells):
                continue
            tabelle.append(cells); continue
        m = re.match(r'^(?:[-*•]|\d+[.)])\s+(.*)$', s)
        if m:
            if para or tabelle: flush()
            nummeriert = bool(re.match(r'^\d', s))
            if liste is None or liste['nummeriert'] != nummeriert:
                if liste: flush()
                liste = {'nummeriert': nummeriert, 'items': []}
            liste['items'].append(m.group(1)); continue
        if liste or tabelle:
            flush()
        para.append(s)
    flush()
    return seiten


def kapitel_bauen():
    out = []
    for praefix, slug, nummer, titel in KAPITEL:
        pfad, fallback = abschnitt_datei(praefix)
        text = open(pfad, encoding='utf-8').read()
        seiten = [s for s in seiten_parsen(text, modern=True) if s['bloecke']]
        out.append({'slug': slug, 'nummer': modernisieren(nummer), 'titel': modernisieren(titel), 'seiten': seiten,
                    'woerter': sum(len(re.findall(r'\w+', b.get('neu', ''))) for s in seiten for b in s['bloecke'])
                    + sum(len(re.findall(r'\w+', i['neu'])) for s in seiten for b in s['bloecke'] if b['typ'] == 'liste' for i in b['items']),
                    'quelle_fallback': fallback})
    return out


def vorsatz_bauen():
    pfad, _ = abschnitt_datei('03_')
    return [s for s in seiten_parsen(open(pfad, encoding='utf-8').read(), modern=True) if s['bloecke'] or s.get('bild')]


def inhaltsverzeichnis():
    pfad, _ = abschnitt_datei('23_')
    eintraege = []
    for s in seiten_parsen(open(pfad, encoding='utf-8').read()):
        for b in s['bloecke']:
            if b['typ'] == 'tabelle':
                for z in b['zeilen']:
                    if len(z) >= 2 and z[0] != 'Inhalt':
                        # Kapitelverweise folgen der Lesefassung; Titel zu Bildtafeln bleiben historisch.
                        kapiteltext = z[1].isdigit() and 5 <= int(z[1]) <= 80
                        eintraege.append({'titel': modernisieren(z[0]) if kapiteltext else z[0], 'seite': z[1]})
    return eintraege


def manifest():
    m = json.load(open(os.path.join(ROOT, 'raw', 'manifest.json'), encoding='utf-8'))
    for e in m:
        e['name'] = os.path.basename(e['file'])
    return m


def tafeln_bauen(man):
    gruppen = []
    details = [e for e in man if e.get('crop_fraction') and '/details/' in e['file']]
    for praefix, slug, titel in TAFELGRUPPEN:
        pfad, _ = abschnitt_datei(praefix)
        seiten = seiten_parsen(open(pfad, encoding='utf-8').read())
        gruppe = {'slug': slug, 'titel': titel, 'text': [], 'tafeln': []}
        for s in seiten:
            if s.get('bild') and s['bild'].startswith('tafel_'):
                name = os.path.splitext(s['bild'])[0]
                js = os.path.join(KORR, 'tafeln', name + '.json')
                nr = re.match(r'tafel_(\d+(?:-\d+)?)', name).group(1)
                tafel = {'nr': nr, 'seite': s['nr'], 'bild': s['bild'], 'titel': s.get('bild_alt', '').split(': ', 1)[-1],
                         'beschriftungen': [], 'details': []}
                if os.path.exists(js):
                    d = json.load(open(js, encoding='utf-8'))
                    tafel['titel'] = d.get('titel') or tafel['titel']
                    if d.get('seite'): tafel['seite'] = str(d['seite'])
                    for b in d.get('beschriftungen', []):
                        de = plain(b.get('de') or '')
                        eintrag = {}
                        if de:
                            r = frakturisieren(de)
                            eintrag.update({'de_neu': de, 'de_alt': r.alt})
                            if r.antiqua: eintrag['antiqua'] = [list(x) for x in r.antiqua]
                        if b.get('fr'): eintrag['fr'] = plain(b['fr'])
                        if b.get('nr'): eintrag['nr'] = str(b['nr'])
                        if b.get('gruppe'): eintrag['gruppe'] = True
                        if eintrag: tafel['beschriftungen'].append(eintrag)
                    if d.get('unsicher'): tafel['unsicher'] = d['unsicher']
                else:
                    tafel['ohne_transkription'] = True
                for e in details:
                    if str(e.get('printed_page')) in {tafel['seite']} | set(tafel['seite'].replace('–', '-').split('-')):
                        tafel['details'].append({'bild': e['name'], 'crop': e['crop_fraction']})
                # Erläuterungstext derselben Seite (z. B. Schemata-Legenden im Fließtext)
                tafel['text'] = s['bloecke']
                gruppe['tafeln'].append(tafel)
            elif s['bloecke']:
                gruppe['text'].append({'seite': s['nr'], 'titel': s['titel'], 'bloecke': s['bloecke']})
        gruppen.append(gruppe)
    return gruppen


def menus_bauen():
    out = []
    for praefix, slug, titel in (('20_', 'menus', 'Muster von Menus'), ('21_', 'tischkarten', 'Amerikanische Tischkarten')):
        pfad, _ = abschnitt_datei(praefix)
        seiten = seiten_parsen(open(pfad, encoding='utf-8').read())
        gruppe = {'slug': slug, 'titel': titel, 'text': [], 'karten': []}
        for s in seiten:
            if s.get('bild'):
                name = os.path.splitext(s['bild'])[0]
                js = os.path.join(KORR, 'menus', name + '.json')
                karte = {'bild': s['bild'], 'titel': s['titel'] or s.get('bild_alt', ''), 'zeilen': []}
                if os.path.exists(js):
                    d = json.load(open(js, encoding='utf-8'))
                    karte['titel'] = d.get('titel') or karte['titel']
                    karte['ort_datum'] = d.get('ort_datum') or ''
                    karte['sprache'] = d.get('sprache', 'de')
                    for z in d.get('zeilen', []):
                        t = plain(z.get('text') or '')
                        if not t: continue
                        if karte['sprache'] == 'de':
                            r = frakturisieren(t)
                            zeile = {'neu': t, 'alt': r.alt, 'art': z.get('art', 'gang')}
                            if r.antiqua: zeile['antiqua'] = [list(x) for x in r.antiqua]
                        else:
                            zeile = {'neu': t, 'alt': t, 'art': z.get('art', 'gang'), 'antiqua': [[0, len(t)]]}
                        karte['zeilen'].append(zeile)
                    if d.get('unsicher'): karte['unsicher'] = d['unsicher']
                else:
                    karte['ohne_transkription'] = True
                gruppe['karten'].append(karte)
            elif s['bloecke']:
                gruppe['text'].append({'seite': s['nr'], 'titel': s['titel'], 'bloecke': s['bloecke']})
        out.append(gruppe)
    return out


def fibel():
    p = os.path.join(HIER, 'fibel.json')
    if not os.path.exists(p):
        return {}
    d = json.load(open(p, encoding='utf-8'))
    for w in d.get('uebungswoerter', []):
        w['alt'] = frakturisieren(w['neu']).alt
    return d


def markdown_bloecke(dateiname, modern, ebenen=False):
    """Absätze einer Markdown-Datei als Textblöcke. `ebenen`: Zahl der Rauten wird zur Überschriftsebene,
    sonst erhält jede Überschrift Ebene 2 (bisheriges Verhalten des Über-Texts)."""
    p = os.path.join(HIER, dateiname)
    if not os.path.exists(p):
        return []
    bloecke = []
    for absatz in open(p, encoding='utf-8').read().split('\n\n'):
        a = absatz.strip()
        if not a: continue
        if a.startswith('#'):
            ebene = min(len(a) - len(a.lstrip('#')), 6) if ebenen else 2
            b = textblock('ueberschrift', a.lstrip('#').strip(), modern=modern, ebene=ebene)
        else:
            b = textblock('absatz', ' '.join(a.split('\n')), modern=modern)
        if b: bloecke.append(b)
    return bloecke


def ueber():
    return markdown_bloecke('ueber.md', modern=True)


def warum():
    """Kapitel „Warum der DVLD dieses Buch gemacht hat“ (tools/warum.md): redaktioneller Text von 2026,
    keine Buchtranskription – deshalb ohne Rechtschreibmodernisierung; Fraktur-Ableitung wie bei allen Texten."""
    bloecke = markdown_bloecke('warum.md', modern=False, ebenen=True)
    assert not bloecke or (bloecke[0]['typ'] == 'ueberschrift' and bloecke[0].get('ebene') == 1), 'warum.md beginnt mit # Titel'
    return bloecke


def bilder_pruefen(daten):
    referenzen = set()
    for s in daten['vorsatz']:
        if s.get('bild'): referenzen.add(s['bild'])
    for g in daten['tafeln']:
        for t in g['tafeln']:
            referenzen.add(t['bild'])
            for d in t['details']: referenzen.add(d['bild'])
    for g in daten['menus']:
        for k in g['karten']: referenzen.add(k['bild'])
    vorhanden = set(os.listdir(IMAGES)) if os.path.isdir(IMAGES) else set()
    fehlt = sorted(referenzen - vorhanden)
    waisen = sorted(vorhanden - referenzen)
    return fehlt, waisen


def main():
    man = manifest()
    daten = {
        'version': 1,
        'buch': {'titel': 'Servierkunde', 'untertitel': 'Ein Hilfsbuch zur Unterstützung des Unterrichtes in der praktischen und theoretischen Servierkunde',
                 'autoren': 'Adolf Fr. Heß, unter Mitwirkung von Karl Scheichelbauer und Anton Sirowy',
                 'ort_jahr': 'Wien, 1899. Selbstverlag der Schuldirektion.',
                 'einband': 'Servierkunde_1899_Einband.jpg', 'titelblatt': 'Servierkunde_1899_Titelblatt.jpg'},
        'vorsatz': vorsatz_bauen(),
        'kapitel': kapitel_bauen(),
        'inhaltsverzeichnis': inhaltsverzeichnis(),
        'tafeln': tafeln_bauen(man),
        'menus': menus_bauen(),
        'fibel': fibel(),
        'ueber': ueber(),
        'warum': warum(),
    }
    fehlt, waisen = bilder_pruefen(daten)
    os.makedirs(CONTENT, exist_ok=True)
    os.makedirs(os.path.join(HIER, 'review_site', 'out'), exist_ok=True)
    json.dump({'unsicher': statistik['unsicher_liste'], 'fallback': statistik['fallback']},
              open(os.path.join(HIER, 'review_site', 'out', 'text_status.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    pfad = os.path.join(CONTENT, 'content.json')
    json.dump(daten, open(pfad, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print(f'content.json: {os.path.getsize(pfad) // 1024} KB, {statistik["bloecke"]} Blöcke, {statistik["woerter"]} Wörter, '
          f'{statistik["unsicher"]} unsichere Stellen entmarkt')
    for k in daten['kapitel']:
        seiten = [s['nr'] for s in k['seiten']]
        print(f"  {k['slug']:14s} {len(seiten):3d} Seiten {seiten[0] if seiten else '-'}–{seiten[-1] if seiten else '-'} {k['woerter']:6d} W"
              + ('  [ROH, nicht korrigiert]' if k['quelle_fallback'] else ''))
    ohne = [t['nr'] for g in daten['tafeln'] for t in g['tafeln'] if t.get('ohne_transkription')]
    print(f"  Tafeln: {sum(len(g['tafeln']) for g in daten['tafeln'])}, ohne Transkription: {ohne or 'keine'}")
    print(f"  Menus/Karten: {sum(len(g['karten']) for g in daten['menus'])}, Inhaltsverzeichnis: {len(daten['inhaltsverzeichnis'])} Einträge")
    if fehlt: print('  FEHLENDE Bilder:', fehlt)
    if waisen: print('  Bild-Waisen (nicht referenziert):', waisen)
    if statistik['fallback']: print('  Fallback auf Rohtext für:', statistik['fallback'])
    return 1 if fehlt else 0


if __name__ == '__main__':
    sys.exit(main())
