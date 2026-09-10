"""Gemeinsame Textsegmentierung, ohne TTS-Anbieter oder Netzwerkzugriff."""
import re

MAX_WOERTER = 1400
SATZENDE = '.!?'

# Anzeige-Token → gesprochen (Kleinschreibung; Großschreibung des Originals wird übernommen)
AUSSPRACHE = {
    'etc.': 'et cetera', 'fl.': 'Gulden', 'kr.': 'Kreuzer', 'nr.': 'Nummer', 'z. b.': 'zum Beispiel', 'z.b.': 'zum Beispiel',
    'u. s. w.': 'und so weiter', 'u. s. f.': 'und so fort', 'd. h.': 'das heißt', 'u. dgl.': 'und dergleichen', 'resp.': 'respektive',
    'bezw.': 'beziehungsweise', 'ca.': 'circa', 'vgl.': 'vergleiche', 'k. k.': 'kaiserlich königlich', 'k. u. k.': 'kaiserlich und königlich',
    'capitel': 'Kapitel', 'capitels': 'Kapitels', 'couvert': 'Kuvert', 'couverts': 'Kuverts', 'couvertpreise': 'Kuvertpreise',
    'couvertpreis': 'Kuvertpreis', 'doctor': 'Doktor', 'officier': 'Offizier', 'officiere': 'Offiziere', 'officieren': 'Offizieren',
    'lieutenant': 'Leutnant', 'oberlieutenant': 'Oberleutnant', 'principal': 'Prinzipal', 'special': 'spezial', 'nothwendig': 'notwendig',
    'räthe': 'Räte', 'räthen': 'Räten', 'excellenz': 'Exzellenz', 'liqueur': 'Likör', 'liqueure': 'Liköre', 'reflectieren': 'reflektieren',
    'clientel': 'Klientel', 'etiquette': 'Etikette', 'menu': 'Menü', 'menus': 'Menüs', 'diner': 'Dinee', 'diners': 'Dinees',
    'dîner': 'Dinee', 'dejeuner': 'Deschönee', 'déjeuner': 'Deschönee', 'souper': 'Supee', 'buffet': 'Büffee', 'consommé': 'Konsomee',
    'restaurateur': 'Restorateur', 'cognac': 'Konjak', 'toilette': 'Toalette', 'local': 'Lokal', 'locale': 'Lokale', 'localität': 'Lokalität',
    'localitäten': 'Lokalitäten', 'thür': 'Tür', 'thüre': 'Türe', 'thüren': 'Türen', 'director': 'Direktor', 'directors': 'Direktors',
}
TOKEN = re.compile(r"z\. ?B\.|u\. ?s\. ?w\.|u\. ?s\. ?f\.|d\. ?h\.|u\. ?dgl\.|k\. ?u\. ?k\.|k\. ?k\.|etc\.|fl\.|kr\.|Nr\.|resp\.|bezw\.|ca\.|vgl\."
                   r"|[A-Za-zÄÖÜäöüßÀ-ÿœŒ]+(?:['’][A-Za-zÄÖÜäöüßÀ-ÿœŒ]+)*|\d+|\s+|.", re.S)
WORTZEICHEN = re.compile(r"[A-Za-zÄÖÜäöüßÀ-ÿœŒ\d]")


def gesprochen_tokens(text):
    """[(anzeige_start, anzeige_ende, gesprochen, ist_wort)] – gesprochener Text als Verkettung der 3. Spalte."""
    out = []
    for m in TOKEN.finditer(text):
        tok = m.group(0)
        low = re.sub(r'\s+', ' ', tok.lower())
        ist_wort = bool(WORTZEICHEN.search(tok))
        ersatz = AUSSPRACHE.get(low)
        if ersatz is None and low.endswith('.') and low[:-1] in AUSSPRACHE:
            ersatz = AUSSPRACHE[low[:-1]] + '.'
        if ersatz is not None and tok[:1].isupper() and ersatz[:1].islower():
            ersatz = ersatz[0].upper() + ersatz[1:]
        out.append((m.start(), m.end(), ersatz if ersatz is not None else tok, ist_wort))
    return out


def segmente_kapitel(kapitel):
    """Vorlese-Einheiten eines Kapitels: (seite_index, block_index, item_index, text, seite_nr, woerter)."""
    segs = []
    for si, seite in enumerate(kapitel['seiten']):
        for bi, b in enumerate(seite['bloecke']):
            if b['typ'] == 'liste':
                for ii, it in enumerate(b['items']):
                    segs.append((si, bi, ii, it['neu'], seite['nr']))
            elif b['typ'] == 'tabelle':
                continue
            else:
                segs.append((si, bi, -1, b['neu'], seite['nr']))
    return segs


def teile(segs):
    """An Seitengrenzen in Stücke ≤ MAX_WOERTER Wörter teilen."""
    stuecke, aktuell, woerter = [], [], 0
    letzte_seite = None
    for s in segs:
        w = len(re.findall(r'\w+', s[3]))
        if aktuell and s[0] != letzte_seite and woerter + w > MAX_WOERTER:
            stuecke.append(aktuell); aktuell, woerter = [], 0
        aktuell.append(s); woerter += w; letzte_seite = s[0]
    if aktuell:
        stuecke.append(aktuell)
    return stuecke
