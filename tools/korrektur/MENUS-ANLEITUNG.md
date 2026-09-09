# Anleitung: Menükarten transkribieren

Buch „Servierkunde“ (Wien 1899), Abschnitt „Muster von Menus“ und „Amerikanische Tischkarten“. Die Bilder unter `/home/mario/herrober-build/raw/menus/` zeigen gedruckte Menükarten (deutsch in Fraktur, französisch/englisch in Antiqua, teils zweifarbig).

## Vorgehen je Bild
1. Bild mit dem Read-Tool öffnen und vollständig lesen (Ort, Datum, Anlass, Titel, Gänge, Weine, Vignetten-Text).
2. Vorhandene Transkription in der genannten Markdown-Datei lesen (Abschnitt `### Unbezifferte Musterseite · …`); sie ist meist brauchbar, aber am Bild zu prüfen und zu vervollständigen.
3. Schreibweise: Original beibehalten (Fraktur-ſ als s, Akzente im Französischen korrekt, englische Begriffe wie im Original). Zeilen des Menus in Originalreihenfolge.

## Ausgabe je Bild (Write-Tool)
Datei: `/home/mario/herrober-build/tools/korrektur/menus/<bildname ohne .jpg>.json`
```json
{"file": "01_Koenigliche_Mittagstafel_1894.jpg", "titel": "Königliche Mittagstafel", "ort_datum": "Abbazia, den 20. März 1894.",
 "sprache": "de",
 "zeilen": [{"text": "Solferino-Suppe", "art": "gang"}, {"text": "Weine:", "art": "ueberschrift"}, {"text": "Château Lafite", "art": "wein"}],
 "unsicher": ["…"]}
```
`art`: eine von `titel`, `ueberschrift`, `gang`, `wein`, `sonstiges`. `sprache`: `de`, `fr` oder `en` (Hauptsprache der Karte). Unlesbares in `unsicher`, nicht raten.
Antworte am Ende nur mit einer Zeile pro Bild: Dateiname + Anzahl Zeilen + Unsicherheiten.
