# Anleitung: Tafelbeschriftungen aus den Bildern transkribieren

Buch „Servierkunde“ (Wien 1899). Die Bildtafeln zeigen Geschirr, Gläser, Bestecke, Gedeck-Schemata mit Beschriftungen: deutsche Bezeichnung in Fraktur (z. B. „Tiſch=Gabel.“), darunter/daneben die französische in Antiqua („Fourchette de table.“). Am oberen Rand steht „Tafel N“ und die Seitenzahl, am unteren Rand mitunter „Sch. S. H., Servierkunde.“ und eine Bogensignatur (Zahl) – beides ist KEINE Beschriftung.

## Vorgehen je Bild
1. Bild mit dem Read-Tool öffnen (Pfad unter `/home/mario/herrober-build/raw/plates/…`). Sorgfältig alle Beschriftungen lesen, von oben nach unten, links nach rechts.
2. Zum Abgleich die OCR-Rohfassung in der genannten Markdown-Datei lesen (Abschnitt `### Seite N · Tafel N` → Block `**Transkription der Beschriftungen:**`). Die OCR ist oft Müll („Eje-Beftel“ = „Eß-Besteck“), das Bild hat Vorrang.
3. Schreibweise: Deutsch in normaler Schrift (langes ſ als s, Fraktur-Bindestrich „=“ als „-“): „Tisch-Gabel.“, „Eß-Besteck.“, „Fisch-Messer.“ Punkt am Ende behalten, wenn er im Bild steht. Französisch mit Akzenten: „Fourchette à poisson.“ Orthographie 1899 belassen (z. B. „Couvert“, „Dessert-Messer“, „Mocca“).
4. Gruppen erhalten: Eine Überschrift wie „Eß-Besteck. — Service de table.“ ist ein Eintrag mit `gruppe: true`; die Einzelteile darunter sind normale Einträge.
5. Nummern in Gedeck-Schemata (Tafel 41–54: „1. Suppenteller, 2. …“) als Einträge mit `nr`.

## Ausgabe je Bild (Write-Tool)
Datei: `/home/mario/herrober-build/tools/korrektur/tafeln/<bildname ohne .jpg>.json`
```json
{"file": "tafel_10_Tisch_und_Fischbesteck.jpg", "tafel": "10", "seite": "97",
 "titel": "Tisch- und Fischbesteck",
 "beschriftungen": [
   {"de": "Eß-Besteck.", "fr": "Service de table.", "gruppe": true},
   {"de": "Tisch-Gabel.", "fr": "Fourchette de table."},
   {"de": "Tisch-Messer.", "fr": "Couteau de table."},
   {"nr": "1", "de": "Suppenteller", "fr": null}
 ],
 "unsicher": ["…"]}
```
`titel`: kurze Bezeichnung der Tafel in der Schreibweise des Buches (aus den Beschriftungen abgeleitet, z. B. „Tisch- und Fisch-Besteck“). `seite` und `tafel` aus dem Bildkopf. Unlesbares in `unsicher` nennen, nicht raten. Keine Erfindungen: nur, was im Bild steht.
Antworte am Ende nur mit einer Zeile pro Bild: Dateiname + Anzahl Einträge + Unsicherheiten.
