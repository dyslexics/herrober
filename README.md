# Herr Ober! – Servierkunde 1899

iOS-App (SwiftUI, iOS 17+) zum Lesen und Hören des gemeinfreien Wiener Lehrbuchs „Servierkunde“ (Adolf Fr. Heß, unter Mitwirkung von Karl Scheichelbauer und Anton Sirowy, Wien 1899): Originaltext in alter Schrift (Fraktur mit langem ſ) oder neuer Schrift, Vorlesen mit Wortmarkierung, Wort-Lupe, restaurierte Bildtafeln, Menus und eine Fraktur-Fibel. Ein Projekt des DVLD e. V. mit dem EÖDL. Kostenlos, ohne Werbung, ohne Datensammlung.

Website: https://appsthrum.com/herrober/

Die Lesetexte verwenden heutige deutsche Rechtschreibung in beiden Schriftansichten. Historische
Quelldateien, Bildbeschreibungen und Menükarten bleiben erhalten.
Die redaktionellen Ersetzungen und ihre Abgrenzung stehen in `docs/rechtschreibung.md`.
Der Einband auf der Startseite öffnet sich beim Antippen bildschirmfüllend mit Zoom.

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
