# Sprechtexte und Rückgabeformat

**Start für die andere LLM:** [Arbeitsauftrag](../docs/VERTONUNG_PROMPT.md).
Technische Anleitung: [Export, Prüfung und Audioimport](../docs/VERTONUNG.md).

Dieser Ordner enthält **1.204 Aufträge**: 970 deutsche Texte mit **Charon**, 225 französische
und 9 englische Texte mit jeweils passender Muttersprach-Stimme. Das neue Kapitel
„Warum dieses Buch“ ergänzt die ersten 937 deutschen Aufträge um 33 Texte.
Hier liegen noch keine neu erzeugten Aufnahmen.

Wortzeiten müssen vom TTS-/Alignment-Dienst oder aus echtem Forced Alignment der fertigen
WAVs stammen. Die vollständigen Vorgaben stehen im [Arbeitsauftrag](../docs/VERTONUNG_PROMPT.md).

**[Übergabepaket mit Prompt und Prüfwerkzeugen herunterladen](HerrOber-Vertonung.zip)**

- [`TEXTS.md`](TEXTS.md): alle Sprechtexte zum Lesen.
- [`texts.jsonl`](texts.jsonl): eine Auftragszeile je Aufnahme.
- [`manifest.json`](manifest.json): Textbindung, Tokens, Zielpfade und Quellenabdeckung.
- [`delivery-template.json`](delivery-template.json): Ausgangsdatei für die Rücklieferung.
- [`delivery.schema.json`](delivery.schema.json): Format einer Rücklieferung.

Der Export lässt sich mit `.venv/bin/python tools/narration.py export` aus dem aktuellen
Inhaltsbestand neu erstellen. Generierte Texte/IDs im Export nicht von Hand ändern.
