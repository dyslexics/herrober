#!/usr/bin/env python3
"""Build der separat gekennzeichneten Lernredaktion; alle Buchbelege werden aufgelöst."""
import json
import re
import unicodedata
from pathlib import Path
from lernredaktion import GLOSSAR, FRAGEN, KONTEXTE
from fraktur import frakturisieren

ROOT = Path(__file__).resolve().parent.parent
C = json.loads((ROOT / 'Content/content.json').read_text())
K = {k['slug']: k for k in C['kapitel']}
TAFELN = {t['nr']: t for g in C['tafeln'] for t in g['tafeln']}
MENU = '03_Johann_Strauss_Jubilaeum_1894.jpg'

def norm(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s.lower().replace('ſ', 's')) if not unicodedata.combining(c))

def texte(blocks):
    for b in blocks:
        if b.get('neu'): yield b['neu']
        yield from texte(b.get('items', []))

def quelle(ref, anker=None):
    if isinstance(ref, int): ref = f'capitel-{ref:02}'
    if ref.isdigit() and ref not in TAFELN: ref = ref.zfill(2)
    if ref in TAFELN:
        t = TAFELN[ref]
        return dict(art='tafel', id=ref, seite=t['seite'], titel=f"Tafel {ref} · S. {t['seite']}", zitat=None)
    if ref == MENU:
        return dict(art='menu', id=ref, seite=None, titel='Johann Strauss Jubiläum · Wien, 15. Oktober 1894', zitat=None)
    k = K[ref]
    hits = [(s, t) for s in k['seiten'] for t in texte(s['bloecke']) if anker and norm(anker) in norm(t)]
    if anker and not hits: raise ValueError(f'Fehlender Beleg: {ref} / {anker}')
    s, t = hits[0] if hits else (k['seiten'][0], None)
    return dict(art='kapitel', id=ref, seite=s['nr'], titel=f"{k['nummer'] or k['titel']} · S. {s['nr']}", zitat=t)

def ziel(art, id='', seite=None): return dict(art=art, id=id, seite=seite)

def glossar():
    out=[]
    for id, titel, aliases, text, anwendung, ref in GLOSSAR:
        # Ganze Fremdwortgruppen nur im passenden Zusammenhang erkennen.
        if id == 'table-dhote': aliases = ['Table d’hôte', "Table d'hôte"]
        if id == 'a-la-carte': aliases = ['à la carte']
        if id == 'hors-doeuvre': aliases = ['Hors-d’œuvre', "Hors-d'œuvre", "Hors-d'oeuvre", 'Hors d’œuvre']
        anker = next((a for a in aliases if ref in K and any(norm(a) in norm(t) for s in K[ref]['seiten'] for t in texte(s['bloecke']))), None)
        out.append(dict(id=id,titel=titel,formen=aliases,text=text,anwendung=anwendung,quelle=quelle(ref,anker)))
    return out

def fragen():
    out=[]
    for n,anker,frage,richtig,a,b,erklaerung in FRAGEN:
        i=sum(f['kapitel']==f'capitel-{n:02}' for f in out)+1
        optionen=[richtig,a,b]
        rotation=(n+i)%3
        optionen=optionen[rotation:]+optionen[:rotation]
        out.append(dict(id=f'k{n:02}-{i}',kapitel=f'capitel-{n:02}',frage=frage,antworten=optionen,richtig=optionen.index(richtig),erklaerung=erklaerung,quelle=quelle(n,anker)))
    return out

def schritt(id,titel,text,art,zid='',seite=None):
    return dict(id=id,titel=titel,text=text,ziel=ziel(art,zid,seite))

def touren():
    return [
      dict(id='erste-schicht',titel='Deine erste Schicht im Jahr 1899',dauer='10–15 Minuten',text='Vom Gruß bis zum gedeckten Platz: Entdecke sechs kleine Aufgaben des Kellners.',schritte=[
        schritt('gruss','Ein Gast kommt herein','Lies, wer den Gast begrüßen soll. Was sagt die Stelle über die Arbeitsteilung?','kapitel','capitel-01',quelle(1,FRAGEN[0][1])['seite']),
        schritt('hangerl','Ein unbekanntes Wort','Lerne das Hangerl kennen. Welche Arbeit übernimmt dieses Tuch?','begriff','hangerl'),
        schritt('tragen','Gut vorbereitet','Lies die Stelle zum Auftragbrett. Denke dir einen Weg mit mehreren Gegenständen aus.','kapitel','capitel-02',quelle(2,FRAGEN[4][1])['seite']),
        schritt('besteck','Genau hinschauen','Erkenne das Fischmesser an seiner Form.','bild','fischmesser'),
        schritt('decken','Decke einen Platz','Ordne Gabel, Messer und Löffel nach der Vorlage zu.','bild','gedeck'),
        schritt('rueckblick','Was ist hängen geblieben?','Beantworte drei Fragen zur Handhabung der Utensilien. Du kannst jederzeit die Buchstelle öffnen.','fragen','capitel-02')]),
      dict(id='festabend',titel='Ein Festabend bei Johann Strauss',dauer='10–15 Minuten',text='Eine historische Menükarte führt dich von der Feier zur Speisenfolge und zur Festtafel.',schritte=[
        schritt('karte','Die Karte selbst','Sieh dir Schrift, Schmuck, Datum und Speisen auf der Originalkarte an.','menu',MENU),
        schritt('gaenge','Gang für Gang','Entschlüssle die französischen Bezeichnungen und entdecke die Reihenfolge.','menuhilfe',MENU),
        schritt('entremets','Ein Wort mit mehreren Bedeutungen','Warum bedeutet Entremets nicht überall dasselbe?','begriff','entremets'),
        schritt('mitte','Der Ehrenplatz','Lies, wo der größte Aufsatz der Festtafel stehen soll.','kapitel','capitel-09',quelle(9,'Der größte und schönste Aufsatz')['seite']),
        schritt('schere','Ein Werkzeug zum Dessert','Finde die Traubenschere und vergleiche sie mit dem Nussknacker.','bild','traubenschere'),
        schritt('festfragen','Eine Feier verstehen','Prüfe dein Verständnis des Festtafelkapitels.','fragen','capitel-09')]),
      dict(id='festessen',titel='Ein Festessen vorbereiten',dauer='8–12 Minuten',text='Von der Speisenfolge zur Festtafel: Was muss vor einem großen Essen vorbereitet werden?',schritte=[
        schritt('folge','Die Speisenfolge','Lies im dritten Kapitel, wie die Speisen einer Mahlzeit aufeinander folgen.','kapitel','capitel-03',K['capitel-03']['seiten'][0]['nr']),
        schritt('entremets','Ein Gang mit Gemüse','Lerne die Bezeichnung Entremets de légumes kennen.','begriff','entremets'),
        schritt('anlass','Eine besondere Gelegenheit','Welche Anlässe nennt das Buch für eine Festtafel?','kapitel','capitel-09',K['capitel-09']['seiten'][0]['nr']),
        schritt('tafelform','Platz für eine Gesellschaft','Sieh dir die U-förmige Festtafel an. Wo liegen die offenen und die geschlossenen Seiten?','tafel','52'),
        schritt('satz','Eine Anweisung lesen','Lies einen der Sätze aus dem Buch in Fraktur und vergleiche mit der neuen Schrift.','leseuebungen','satz'),
        schritt('verstanden','Die Folge verstehen','Beantworte drei Fragen zur Speisenfolge.','fragen','capitel-03')])]

def leseuebungen():
    gruppen=[(2,'Das Serviertuch'),(2,'auf einmal zu tragen'),(3,'warmen Mehlspeisen vor den kalten'),(4,'vier bis sechs Personen'),(7,'zwei Finger breit vom Rande'),(9,'Der größte und schönste Aufsatz')]
    saetze=[(1,'Die dem Gaste zunächst stehenden'),(2,'Hat man vieles auf einmal zu tragen'),(3,'Kompott einen Gang für sich'),(7,'Die Gabel hat stets links'),(9,'Wird hingegen der Kaffee an der Tafel serviert'),(10,'Das Vergessen einer einzigen Gabel')]
    out=[]
    for stufe,alle in [('gruppe',gruppen),('satz',saetze)]:
        for i,(k,anker) in enumerate(alle):
            q=quelle(k,anker)
            if stufe=='gruppe':
                start=norm(q['zitat']).index(norm(anker)); text=q['zitat'][start:start+len(anker)]
            else:
                text=next(s.strip() for s in re.split(r'(?<=[.!?])\s+',q['zitat']) if norm(anker) in norm(s))
            f=frakturisieren(text)
            out.append(dict(id=f'{stufe}-{i+1}',stufe=stufe,neu=text,alt=f.alt,antiqua=f.antiqua,map=f.map,quelle=q))
    return out

def bilder():
    # Normierte Bildfenster; unveränderte vorhandene Tafel, nur im UI ausgeschnitten.
    return [
      dict(id='fischmesser',titel='Finde das Fischmesser',text='Welcher Ausschnitt zeigt das Fischmesser? Vergleiche die Klingen und die Form der Spitze.',quelle=quelle('10'),bild=TAFELN['10']['bild'],art='auswahl',richtig=1,
        optionen=[dict(titel='A',beschreibung='Langes gerades Messer mit abgerundeter Spitze',crop=[.39,.05,.16,.61]),dict(titel='B',beschreibung='Breites verziertes Messer mit spitzer Klinge, waagrecht',crop=[.09,.711,.80,.063]),dict(titel='C',beschreibung='Löffel mit ovaler Schale und langem Stiel',crop=[.65,.23,.16,.43])],
        erklaerung='B ist das Fischmesser. Es liegt auf Tafel 10 waagrecht unter dem Tischbesteck. Die Bildunterschrift bestätigt die Zuordnung.'),
      dict(id='traubenschere',titel='Finde die Traubenschere',text='Welcher Ausschnitt zeigt die Schere zum Abteilen von Trauben? Die Formen helfen dir beim Vergleich.',quelle=quelle('19'),bild=TAFELN['19']['bild'],art='auswahl',richtig=2,
        optionen=[dict(titel='A',beschreibung='Kräftiges Werkzeug mit zwei geriffelten Griffen',crop=[.20,.09,.13,.375]),dict(titel='B',beschreibung='Schmales spitzes Werkzeug mit einem Griff',crop=[.50,.16,.07,.305]),dict(titel='C',beschreibung='Schere mit zwei runden Grifföffnungen',crop=[.71,.12,.17,.345])],
        erklaerung='C ist die Traubenschere. Daneben stehen der Nussknacker (A) und der Nussschäler (B). Öffne die Tafel, um die gedruckten Namen zu vergleichen.'),
      dict(id='gedeck',titel='Decke einen Platz',text='Lege drei Teile an ihren Platz: Wähle zuerst ein Besteckteil, dann seine Lage am Teller. Die Übung vereinfacht Tafel 42 auf drei Positionen.',quelle=quelle('42'),bild=TAFELN['42']['bild'],art='anordnen',richtig=0,optionen=[],
        erklaerung='Die Gabel gehört links vom Teller, das Messer rechts. Der kleine Löffel liegt auf dieser Tafel oberhalb des Tellers. Die gedruckte Vorlage nennt fünf Gläser; „Bier Glas“ ist handschriftlich ergänzt und zählt hier nicht mit.')]

def menu():
    # Leseschlüssel, keine behauptete Rekonstruktion von Rezepten oder Gästen.
    teile=[
      ('Anlass und Ort','Johann Strauss Jubiläum · Grand Hôtel, Vienne · 15. Oktober 1894','Die Angaben verorten die Karte in Wien und nennen das Jubiläum. Die Karte allein belegt keine vollständige Gästeliste.'),
      ('Der Auftakt',"Tortue claire à l’Anglaise",'Wörtlich: klare Schildkrötensuppe auf englische Art. Der Name nennt eine historische Speise; eine genaue Rezeptur lässt sich aus dieser Zeile nicht ablesen.'),
      ('Der Fischgang','Fogas à la Chambord · Pommes, sauce tartare','Fogas bezeichnet Zander. Pommes meint hier Kartoffeln; dazu nennt die Karte Sauce tartare. „À la Chambord“ ist ein Zubereitungsname, dessen genaue Ausführung die Karte offenlässt.'),
      ('Fleisch und Beigaben','Pièce de bœuf pré-salé garni à la jardinière','Die Zeile nennt Rindfleisch und eine Garnitur nach Gärtnerart, also mit Gemüse. Welche Gemüse und Mengen verwendet wurden, steht hier nicht.'),
      ('Ein Name im Gericht','Filet de chevreuil à la Jean Strauss','Chevreuil bedeutet Reh: ein Rehfilet, benannt nach Jean Strauss. Die Benennung würdigt den Namen des Jubilars; sie liefert kein vollständiges Rezept.'),
      ('Eine Unterbrechung','Punch à la Romaine','Der Punch steht zwischen dem Rehfilet und dem Geflügel. Entdecke diese Pause in der Speisenfolge und vergleiche im dritten Kapitel die Position von Sorbet vor dem Braten.'),
      ('Geflügel und Beilagen','Chapons de Styrie à la broche · Salade, Compote','Kapaune aus der Steiermark am Spieß, gefolgt von Salat und Kompott. Chapon ist ein kastrierter, für die Küche gemästeter Hahn.'),
      ('Der Ausklang','Glace et Crème · Fromages · Fruits — Dessert · Café','Eis und Creme, Käse, Früchte und Dessert, zuletzt Kaffee. Verfolge die einzelnen Zeilen: Der Abschluss besteht hier aus mehreren Angeboten.'),
      ('Die Getränke','Bière de Dreher · Grinzinger Eigenbau 1885 · Vöslauer Ausstich 1887 · Pommery & Greno frappé · Liqueurs','Bier, benannte Weine mit Jahrgängen, gekühlter Champagner und Liköre stehen auf der Karte. Die räumliche Anordnung allein legt keine genaue Zuordnung jedes Getränks zu einem Gang fest.'),
      ('Dein Blick auf die Karte','Was verrät eine Menükarte?','Finde drei Dinge: den Anlass, einen Gang mit Ortsbezug und die Stelle des Kaffees. Vergleiche anschließend mit einer anderen Karte der Sammlung.')]
    karte=next(m for g in C['menus'] for m in g['karten'] if m['bild']==MENU)
    zeilen=karte['zeilen']
    gruppen=[[0,19,1],[3],[4,5],[6],[7],[8],[9,10],[11,12,13,14],[15,16,17,18]]
    abschnitte=[]
    for i,(t,z,x) in enumerate(teile):
        if i<len(gruppen): z=' · '.join(zeilen[j]['neu'] for j in gruppen[i])
        abschnitte.append(dict(id=f'm{i+1}',titel=t,zitat=z,text=x,sprache='fr-FR' if 1<=i<=7 else 'de-AT'))
    return [dict(id='strauss',menu=MENU,titel='Ein Festabend, Gang für Gang',text='Ein Leseschlüssel zur Karte von 1894. Die Erläuterungen sind heutige Ergänzungen; den genauen Wortlaut findest du auf der Originalkarte.',quelle=quelle(MENU),abschnitte=abschnitte,links=[dict(titel='Fogas / Zander · Treccani',url='https://www.treccani.it/enciclopedia/sandra_%28Enciclopedia-Italiana%29/'),dict(titel='Chapon · Académie française',url='https://www.dictionnaire-academie.fr/article/A9C1642')])]

def build():
    return dict(version=1,begriffe=glossar(),fragen=fragen(),touren=touren(),kontexte=[dict(id=id,titel=t,text=x,quelle=quelle(k,a)) for id,t,k,x,a in KONTEXTE],leseuebungen=leseuebungen(),bildaufgaben=bilder(),menufuehrer=menu())

if __name__=='__main__':
    daten=build()
    target=ROOT/'Content/lernen.json'
    target.write_text(json.dumps(daten,ensure_ascii=False,indent=2)+'\n')
    print(', '.join(f'{len(v)} {k}' for k,v in daten.items() if isinstance(v,list)))
