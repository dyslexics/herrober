#!/usr/bin/env python3
"""Fraktur-Ableitung: Antiqua-Text (neu) → Fraktur-Text (alt) mit langem ſ, Heyse-ſs und ꝛc.

Regeln (Duden-Fraktursatz um 1900, Heysesche s-Schreibung wie im Buch):
  rundes s  – am Wortende; am Silbenende vor einer Trennfuge (Aus-drücke, Häus-chen, Diens-tag, Arbeits-amt);
              vor Ableitungssuffix (Häus-lein, les-bar)
  langes ſ  – sonst: Silbenanlaut, ſp/ſt/ſch/ſk innerhalb der Silbe (Gaſt, Fenſter, Waſſer, Tiſch, Weſpe, Maske→Maſke)
  ss        – vor Vokal innerhalb des Stammes: ſſ (Waſſer, Meſſer); am Wortende oder vor Konsonant: ſs (daſs, muſs,
              Bewuſstſein); an Kompositafuge (aus+sicht, Glas+schale): s + ſ (Ausſicht, Glasſchale)
  etc.      – ꝛc. (Fraktur-Abkürzung), Zeichenlänge ändert sich (4 → 3), daher Zeichen-Map
  Antiqua   – nicht eingedeutschte Fremdwörter (Menu, Déjeuner, à la fourchette …) bleiben ohne ſ, Bereich wird gemeldet

Silbenfugen kommen aus den traditionellen Trennmustern hyph-de-1901 (tools/hyph-de-1901.dic), nicht aus der
Rechtschreibung von 1996 (dort wird „Fens-ter“ getrennt, das ergäbe ein falsches rundes s). 1901 trennt „Wes-pe“
und „Mas-ke“, im Fraktursatz steht dort trotzdem ſ (gleiche Silbe im Sinne des Satzes) – daher Sonderfall sp/sk.

API:
  frakturisieren(neu, antiqua=None) -> Ergebnis(alt, map, antiqua, woerter)
    map[i] = Position des Zeichens neu[i] im alt-Text (len = len(neu)+1, map[len(neu)] = len(alt))
    antiqua = Bereiche [a, e) in alt-Koordinaten
  antiqua_bereiche(neu) -> automatisch erkannte Antiqua-Bereiche in neu-Koordinaten
"""
import json
import os
import re
from dataclasses import dataclass, field

import pyphen

HIER = os.path.dirname(os.path.abspath(__file__))
DIC = os.path.join(HIER, 'hyph-de-1901.dic')
AUSNAHMEN = os.path.join(HIER, 'fraktur_ausnahmen.json')

LANG_S = 'ſ'
VOKALE = set('aeiouäöüyáàâéèêíìîóòôúùûAEIOUÄÖÜY')
BUCHSTABE = re.compile(r'[A-Za-zÄÖÜäöüßÀ-ÿœŒ]')
WORT = re.compile(r"[A-Za-zÄÖÜäöüßÀ-ÿœŒ]+(?:['’][A-Za-zÄÖÜäöüßÀ-ÿœŒ]+)*")

# Erstglieder/Vorsilben, die auf s enden und vor einem s-Anlaut eine Kompositafuge bilden (aus+sicht → Ausſicht)
FUGEN_S = ('aus', 'dis', 'los', 'haus', 'glas', 'eis', 'reis', 'preis', 'kreis', 'gras',
           'arbeits', 'geburts', 'hochzeits', 'verlobungs', 'jahres', 'festes', 'ordnungs', 'liebes', 'tages', 'abends',
           'mittags', 'morgens', 'gesellschafts', 'rechts', 'staats', 'hofs', 'wirtschafts', 'geschäfts', 'wirts',
           'ausschuss', 'genuss', 'kürbis', 'reibeis', 'obers', 'kaffeehaus', 'gasthaus', 'wirtshaus', 'speisehaus',
           'kalbs', 'rinds', 'schweins', 'lamms', 'hammels', 'ochsens', 'hühner', 'hasen', 'rehs', 'wilds')
# Fremdwörter in Antiqua (Kleinschreibung)
ANTIQUA_LEXIKON = ('menu', 'menus', 'déjeuner', 'dejeuner', 'déjeuners', 'dejeuners', 'dîner', 'dîners', 'souper', 'soupers',
                   'buffet', 'buffets', 'banquet', 'banquets', 'consommé', 'consomme', 'hors', "d'oeuvre", "d'œuvre",
                   'entrée', 'entrées', 'entremets', 'breakfast', 'luncheon', 'dinner', 'supper', 'lunch', "d'hôte",
                   'café', 'garçon', 'maître', 'sommelier', 'potage', 'poisson', 'fromage', 'légumes', 'rôti')
PHRASEN = [re.compile(p, re.I) for p in (r"à la fourchette", r"à la carte", r"table d'h[oô]te", r"hors[- ]d'[oœ]e?uvres?",
                                          r"à la [A-Za-zÀ-ÿ]+", r"de table", r"de luxe", r"en gros", r"en détail")]
AKZENT = re.compile(r'[àâéèêëîïôûùçœÀÂÉÈÊËÎÏÔÛÙÇŒ]')


@dataclass
class Ergebnis:
    alt: str
    map: list
    antiqua: list = field(default_factory=list)
    woerter: list = field(default_factory=list)  # (neu_wort, alt_wort) für Review-Dumps


_trenner = None
_ausnahmen = None


def trenner():
    global _trenner
    if _trenner is None:
        _trenner = pyphen.Pyphen(filename=DIC, left=2, right=2)
    return _trenner


def ausnahmen():
    global _ausnahmen
    if _ausnahmen is None:
        _ausnahmen = json.load(open(AUSNAHMEN, encoding='utf-8')) if os.path.exists(AUSNAHMEN) else {}
    return _ausnahmen


def fugen(wort):
    """Positionen k, an denen nach wort[:k] eine Silbenfuge liegt (aus den 1901-Mustern)."""
    pos = set()
    try:
        ins = trenner().inserted(wort)
    except Exception:
        return pos
    k = 0
    for ch in ins:
        if ch == '-':
            pos.add(k)
        else:
            k += 1
    return pos


def kompositum_fuge(wort, pos):
    """Endet an Position pos ein Erstglied aus FUGEN_S, das am Wortanfang steht (Aus|sicht, Glas|schale, Arbeits|saal)?
    Nur am Wortanfang verankert, sonst träfe „eis“ auch in Weiss|wein (→ Weiſswein, Heyse-ſs vor Konsonant)."""
    unten = wort.lower()
    for v in FUGEN_S:
        if pos == len(v) and unten.startswith(v) and len(wort) - pos >= 3:
            return True
    return False


def wort_frakturisieren(wort):
    """Ein Wort (nur Buchstaben/Apostroph) → Fraktur-Form gleicher Länge."""
    ex = ausnahmen()
    if wort in ex:
        return ex[wort]
    low = wort.lower()
    if low in ex:
        form = ex[low]
        return form[0].upper() + form[1:] if wort[0].isupper() else form
    n = len(wort)
    f = fugen(wort)
    out = []
    i = 0
    while i < n:
        c = wort[i]
        if c != 's':
            out.append(c); i += 1; continue
        if i == n - 1:                                   # Wortende
            out.append('s'); i += 1; continue
        nxt = wort[i + 1]
        if not BUCHSTABE.match(nxt):                     # vor Apostroph (laſſ') → ſ
            out.append(LANG_S); i += 1; continue
        if nxt == 's':
            ende = i + 2 >= n
            folgt_vokal = (not ende) and wort[i + 2] in VOKALE
            if not ende and kompositum_fuge(wort, i + 1):
                out.append('s'); out.append(LANG_S)      # Aus|ſicht, Glas|ſchale
            elif ende or not folgt_vokal:
                out.append(LANG_S); out.append('s')      # daſs, muſs, Bewuſst-
            else:
                out.append(LANG_S); out.append(LANG_S)   # Waſſer
            i += 2; continue
        # Trennfuge direkt nach dem s → rundes s (Aus-drücke, Häus-chen, Diens-tag, Arbeits-amt).
        # sp/sk werden 1901 zwar getrennt (Wes-pe, Mas-ke), im Satz steht ſ – außer an einer Kompositafuge (Aus-putz).
        if ((i + 1) in f and not (nxt in 'pk' and not kompositum_fuge(wort, i + 1))) \
                or (nxt not in VOKALE and kompositum_fuge(wort, i + 1)):
            out.append('s')
        else:
            out.append(LANG_S)
        i += 1
    return ''.join(out)


def antiqua_bereiche(neu):
    """Fremdwörter, die 1899 in Antiqua gesetzt wurden: Phrasen + Lexikon + Akzentbuchstaben."""
    out = []
    belegt = [False] * (len(neu) + 1)
    for rx in PHRASEN:
        for m in rx.finditer(neu):
            out.append((m.start(), m.end()))
            for k in range(m.start(), m.end()):
                belegt[k] = True
    for m in WORT.finditer(neu):
        if belegt[m.start()]:
            continue
        w = m.group(0)
        if AKZENT.search(w) or w.lower() in ANTIQUA_LEXIKON:
            out.append((m.start(), m.end()))
    out.sort()
    merged = []
    for a, e in out:
        if merged and a <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], e))
        else:
            merged.append((a, e))
    return merged


def frakturisieren(neu, antiqua=None):
    if antiqua is None:
        antiqua = antiqua_bereiche(neu)
    antiqua = sorted(antiqua)
    in_antiqua = [False] * (len(neu) + 1)
    for a, e in antiqua:
        for k in range(a, e):
            in_antiqua[k] = True
    alt = []
    mp = [0] * (len(neu) + 1)
    woerter = []
    i = 0
    n = len(neu)
    while i < n:
        mp[i] = len(alt)
        if neu.startswith('etc.', i) and not in_antiqua[i] and (i == 0 or not BUCHSTABE.match(neu[i - 1])):
            mp[i] = len(alt); alt.append('ꝛ')           # e → ꝛ
            mp[i + 1] = len(alt) - 1                     # t → (auf ꝛ)
            mp[i + 2] = len(alt); alt.append('c')        # c → c
            mp[i + 3] = len(alt); alt.append('.')        # . → .
            i += 4
            continue
        m = WORT.match(neu, i)
        if m and not in_antiqua[i]:
            w = m.group(0)
            fw = wort_frakturisieren(w)
            assert len(fw) == len(w), (w, fw)
            for k in range(len(w)):
                mp[i + k] = len(alt)
                alt.append(fw[k])
            if fw != w:
                woerter.append((w, fw))
            i = m.end()
            continue
        alt.append(neu[i])
        i += 1
    mp[n] = len(alt)
    return Ergebnis(''.join(alt), mp, [(mp[a], mp[e]) for a, e in antiqua], woerter)


if __name__ == '__main__':
    import sys
    text = sys.stdin.read() if not sys.stdin.isatty() else \
        'Tritt ein Gast in das Local, so haben ihn die anwesenden Kellner stehend zu begrüßen, dass alle Gäste etc. es sehen; Wasser, Aussicht, Häuschen, Dienstag, Fenster, Menu à la fourchette.'
    r = frakturisieren(text)
    print(r.alt)
    print('antiqua:', [r.alt[a:e] for a, e in r.antiqua])
