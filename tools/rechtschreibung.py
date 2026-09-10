#!/usr/bin/env python3
"""Heutige Rechtschreibung für Lesetexte, vor der Fraktur-Ableitung.

Nur explizit geprüfte Wörter und Wendungen des Buches werden ersetzt. Keine
allgemeine c/k-, th/t- oder ß/ss-Ersetzung: Namen und Fremdwörter bleiben stehen.
Quellen und Bildbeschreibungen werden nicht durch diese Funktion geschickt.
Grundlage: https://www.rechtschreibrat.com/regeln-und-woerterverzeichnis/
"""
import json
import re
from pathlib import Path

WOERTER = json.loads(Path(__file__).with_name('rechtschreibung_woerter.json').read_text())
WORT = re.compile(r"[^\W\d_]+", re.UNICODE)
# Im Text ausdrücklich als Französisch bezeichnete Ausdrücke bleiben Französisch.
FREMDSPRACHE = re.compile(r"à couvert|le menu|Menu du Buffet|\bLiqueurs(?=:)", re.IGNORECASE)
WENDUNGEN = {
    'im allgemeinen': 'im Allgemeinen',
    'Im allgemeinen': 'Im Allgemeinen',
    'im besonderen': 'im Besonderen',
    'Im besonderen': 'Im Besonderen',
    'im übrigen': 'im Übrigen',
    'Im übrigen': 'Im Übrigen',
    'im vorhinein': 'im Vorhinein',
    'von einander': 'voneinander',
    'zu einander': 'zueinander',
    'weiter bilden': 'weiterbilden',
    'von Liqueurs': 'von Likören',
}
WENDUNG = re.compile(r'(?<!\w)(?:' + '|'.join(map(re.escape, WENDUNGEN)) + r')(?!\w)')


def modernisieren(text):
    """Rechtschreibung ändern, Aussage, Grammatik und historische Fachbegriffe bewahren."""
    text = WENDUNG.sub(lambda m: WENDUNGEN[m.group()], text)
    geschuetzt = [m.span() for m in FREMDSPRACHE.finditer(text)]

    def ersetzen(m):
        if any(a <= m.start() < e for a, e in geschuetzt):
            return m.group()
        return WOERTER.get(m.group(), m.group())

    return WORT.sub(ersetzen, text)
