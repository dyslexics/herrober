# Sprechtexte und Rückgabeformat

**Start für die andere LLM:** [Arbeitsauftrag](../docs/VERTONUNG_PROMPT.md).
Technische Anleitung: [Export, Prüfung und Audioimport](../docs/VERTONUNG.md).

Dieser Ordner enthält den exportierten Textbestand: **1.171 Aufträge** für Deutsch,
Französisch und Englisch. Hier liegen noch keine neu erzeugten Aufnahmen.

**[Übergabepaket mit Prompt und Prüfwerkzeugen herunterladen](HerrOber-Vertonung.zip)**

- [`TEXTS.md`](TEXTS.md): alle Sprechtexte zum Lesen.
- [`texts.jsonl`](texts.jsonl): eine Auftragszeile je Aufnahme.
- [`manifest.json`](manifest.json): Textbindung, Tokens, Zielpfade und Quellenabdeckung.
- [`delivery-template.json`](delivery-template.json): Ausgangsdatei für die Rücklieferung.
- [`delivery.schema.json`](delivery.schema.json): Format einer Rücklieferung.

Der Export lässt sich mit `.venv/bin/python tools/narration.py export` aus dem aktuellen
Inhaltsbestand neu erstellen. Generierte Texte/IDs im Export nicht von Hand ändern.
