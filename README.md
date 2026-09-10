# Herr Ober! – Servierkunde 1899

iOS-App (SwiftUI, iOS 17+) zum Lesen und Hören des gemeinfreien Wiener Lehrbuchs „Servierkunde“ (Adolf Fr. Heß, unter Mitwirkung von Karl Scheichelbauer und Anton Sirowy, Wien 1899): Originaltext in alter Schrift (Fraktur mit langem ſ) oder neuer Schrift, Vorlesen mit Wortmarkierung, Wort-Lupe, restaurierte Bildtafeln, Menus und eine Fraktur-Fibel. Ein Projekt des DVLD e. V. mit dem EÖDL. Kostenlos, ohne Werbung, ohne Datensammlung.

Website: https://appsthrum.com/herrober/

## Vertonung durch eine andere LLM

Der vollständige Textbestand ist als **1.204 Sprechaufträge** vorbereitet, mit festen IDs,
Sprachen und Wortzuordnung. Eine andere LLM kann die Aufnahmen mit ihrem Audiowerkzeug
erzeugen und über die geprüfte Schnittstelle zurückliefern.

**Stimmen:** 970 deutsche Aufträge mit Charon, 225 französische und 9 englische Aufträge mit
je einer passenden Muttersprach-Stimme. Wortzeitmarken kommen vom TTS-/Alignment-Dienst
oder aus echtem Forced Alignment der fertigen WAV-Dateien.

**[Arbeitsauftrag kopieren](docs/VERTONUNG_PROMPT.md)** ·
**[Übergabepaket als ZIP](narration/HerrOber-Vertonung.zip)** ·
**[Audio prüfen und einlesen](docs/VERTONUNG.md)**

```sh
.venv/bin/python tools/narration.py export
.venv/bin/python tools/narration.py validate --delivery narration-incoming/gesamt/delivery.json
.venv/bin/python tools/narration.py import --delivery narration-incoming/gesamt/delivery.json
```

Export und Import erzeugen selbst keine Sprache. Der Import übernimmt Audio samt echten
Wortzeiten und sichert den vorherigen Stand. Kapitel behalten ihren Player; Lerntexte und
Fibel nutzen passende importierte Aufnahmen. Zusätzliche Texte werden unter „Über das Buch →
Weitere Hörtexte“ zugänglich. Ein neuer App-Build ist nach dem Import erforderlich.

## App-Stand

**TestFlight: 1.0 (4)**, am 10.09.2026 für „Mario intern“ bereitgestellt.
Die Audio-Schnittstelle ist vorbereitet. Die vollständige neue Vertonung durch eine andere
LLM steht noch aus; gelieferte Aufnahmen brauchen anschließend einen neuen App-Build.

Die Lesetexte verwenden heutige deutsche Rechtschreibung in beiden Schriftansichten. Historische
Quelldateien, Bildbeschreibungen und Menükarten bleiben erhalten.
Die redaktionellen Ersetzungen und ihre Abgrenzung stehen in `docs/rechtschreibung.md`.
Der Einband auf der Startseite öffnet sich beim Antippen bildschirmfüllend mit Zoom.

Build 4 (10.09.2026): Kapitel „Warum ein Legasthenieverband ein Kellnerbuch von 1899 vertont hat“
(DVLD, nach Dr. Astrid Kopp-Duller) aus `tools/warum.md` → `content.json` „warum“, in „Über das Buch“ als Karte
mit eigener Seite in beiden Schriften (`-screen warum`); App-Icon hellblau statt grün (`tools/gen_icon.py`);
Vertonungsexport um die 33 Kapitelblöcke ergänzt (1.204 Aufträge). Landingpage neu: `/home/mario/appsthrum-herrober/build.py`.

Build 3 ergänzt „Entdecken & lernen“: 40 Begriffserklärungen auch in der Wort-Lupe, drei Touren,
30 Kapitelfragen, drei Bildaufgaben, zwölf Fraktur-Leseübungen, ein kommentiertes Strauss-Menü
und sechs historische Einordnungen. Lernstand und Merkliste bleiben lokal. Die Ergänzungen
lassen sich mit Wortmarkierung anhören. Originales Appsthrum-Banner mit Link am Ende von
„Über das Buch“ und unter dem Rainer-Ternik-Hinweis. Redaktion und Quellen: [Lernbereich](docs/LERNREDAKTION.md).

## Aufbau

- `Sources/` – SwiftUI-App (Models, Data, Design, Views), `Tests/` – Unit-Tests
- `UITests/` – Einband, Lernwege, Wort-Lupe, Wiederholung, Merkliste, Bildaufgaben, Menü, Markenlinks und große Systemschrift
- `Content/` – `content.json`, `lernen.json`, restaurierte Bilder (`Images/`, `Originals/`, `Thumbs/`), Audio mit Wortzeiten (`Audio/`)
- `Fonts/` – UnifrakturMaguntia, UnifrakturCook, Atkinson Hyperlegible (SIL OFL 1.1)
- `tools/` – Inhaltspipeline (Python, venv):
  - `korrektur/` – OCR-korrigierte Kapitel und aus den Bildern transkribierte Tafeln/Menus
  - `fraktur.py` – ſ-Regeln (Trennmuster 1901, Heyse-ſs, ꝛc.), `tests/test_fraktur.py`
  - `build_content.py` → `Content/content.json`
  - `lernredaktion.py` + `build_lernen.py` → `Content/lernen.json` (Belege gegen Buchtext geprüft)
  - `rechtschreibung.py`, `rechtschreibung_woerter.json` – geprüfte Modernisierung nur der Lesetexte
  - `enhance_images.py` – farberhaltende Restaurierung der Scans
  - `build_audio.py` – edge-tts mit WordBoundary, Alignment auf Anzeigetext, AAC
  - `narration.py` – anbieterneutraler Textexport und geprüfter Audioimport; [Anleitung](docs/VERTONUNG.md)
  - `review_site/` – Prüfseiten (Text roh/neu/alt, Bilder vorher/nachher, Hörproben)
  - `sync.sh`, `sim_shots.sh`, `mac_release.sh` – Build auf dem Mac (xcodegen, Simulator, Archiv, Upload)
- `project.yml` – xcodegen-Projekt

## Pipeline

```
tools/korrektur/*.md + tafeln/*.json + menus/*.json
  → .venv/bin/python tools/build_content.py
  → .venv/bin/python tools/build_lernen.py
  → .venv/bin/python tools/enhance_images.py
  → .venv/bin/python tools/build_audio.py          (Hash-Cache, nur Änderungen)
  → ./tools/sync.sh                                 (Mac Studio, xcodegen)
  → ssh macstudio 'bash ~/herrober/tools/sim_shots.sh'
  → ssh macstudio 'bash ~/herrober/tools/mac_archive.sh 3' (Archiv und Export)
```

`mac_release.sh` enthält zusätzlich den externen Upload und gehört nicht zum lokalen Prüfablauf.

## Lizenz

App-Code: GPL-3.0 (siehe `LICENSE`). Buchtext und Abbildungen von 1899 sind gemeinfrei. Schriften unter SIL Open Font License 1.1 (`Fonts/OFL-*.txt`).
