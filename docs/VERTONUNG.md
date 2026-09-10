# Vollständige Vertonung durch eine andere LLM

Die App kann Aufnahmen aus einem beliebigen Sprachgenerator übernehmen. Dieses Repository
liefert die Texte, den Arbeitsauftrag und einen Importer. Der Export und der Import rufen
keinen Sprachdienst auf. Die eigentliche Vertonung führt die beauftragte andere LLM mit
ihrem Audiowerkzeug durch.

**Direkter Einstieg:** [fertigen Prompt kopieren](VERTONUNG_PROMPT.md), dazu den
[ZIP-Übergabeordner](../narration/HerrOber-Vertonung.zip) übergeben. Der Prompt lässt sich unabhängig von
einem bestimmten Modell verwenden.

Das ZIP enthält Texte, Quellen, Prompt und Prüfwerkzeuge. Die andere LLM kann darin ihre
Lieferung prüfen. Zum Einbau gehört die Lieferung in das vollständige App-Repository;
ein Import in die Paketkopie allein aktualisiert keine App. Das Paket lässt sich mit
`.venv/bin/python tools/narration.py bundle` neu erstellen.

## Umfang des Exports

Stand 10.09.2026, einschließlich „Warum dieses Buch“: **1.204 Sprechaufträge**, davon 87
vorhandene Audioteile und 1.117 ergänzende Texte. Sprachen: 970 Deutsch, 225 Französisch,
9 Englisch. Die Zahl der Dateien ist keine
Zahl von Buchseiten: Ein Auftrag kann einen einzelnen Begriff oder mehrere Buchseiten enthalten.

**Verbindliche Stimmen:** Charon für alle deutschen Aufträge; für Französisch und Englisch
je eine passende Muttersprach-Stimme. Gegenüber dem ersten Export mit 937 deutschen Aufträgen
sind 33 deutsche Texte hinzugekommen. Die bisherigen Job-IDs und Job-Hashes bleiben gleich.
Für die aktuelle Lieferung gilt der neue Gesamt-Hash aus `manifest.json`.

**Wortausrichtung:** echte Wortzeitmarken des TTS-/Alignment-Dienstes oder Forced Alignment
auf den fertigen WAV-Dateien. Liefert der Charon-TTS-Dienst keine Wortzeiten, wird die fertige
Charon-Aufnahme ausgerichtet. Die Stimme und die Zeitbasis der Aufnahme bleiben erhalten.
Stimme je Datei in `recordings[].voice`, Alignment-Verfahren und Werkzeug im Prüfbericht nennen.

| Inhalt | Export und Verwendung |
|---|---|
| Kapitel, Listen, Fußnoten, Randtitel | 20 bestehende Kapitelteile; gleiche Seiten-/Blockzuordnung für Reader und Wort-Lupe |
| Tafeln | 53 bestehende deutsche Beschriftungstracks; französische Beschriftungen zusätzlich |
| Menükarten | 14 bestehende Tracks mit der Sprache der Karte; zusätzliche Angaben separat |
| Tabellen | Textzellen in Leserichtung; deutsche und französische Spalte der Gang-Tabelle getrennt |
| Fibel | Einführung, Alphabet, Hinweise, Stolpersteine und Übungswörter |
| Lernen | Glossar, Wortformen, Beispiele, Fragen, Antwortoptionen, Erklärungen, Touren, Bildaufgaben, Leseübungen, historische Einordnung, Menüführer und Quellenzitate |
| Buchangaben | Titel, Autoren, Vorsatz, Inhaltsverzeichnis, „Über das Buch“ und „Warum dieses Buch“ |

Maßgeblich sind die aktuellen `Content/content.json` und `Content/lernen.json`. Der Export
erfasst deren lesbare Textfelder. Er führt identische Texte derselben Sprache zusammen und
listet die ursprünglichen Fundstellen unter `coverage.included` im Manifest auf.
Die zweite Schriftansicht braucht dieselbe Aufnahme. Technische Kennungen, Bildpfade,
interne Unsicherheitsnotizen und absichtlich falsche Fibel-Antworten stehen mit Begründung
unter `coverage.excluded`. Ein neu eingeführtes, unbekanntes Textfeld stoppt den Export,
damit es nicht unbemerkt fehlt.

Bedienknöpfe, dynamische Fortschrittsanzeigen und in Swift formulierte Bedienhinweise bleiben
Teil der iOS-/VoiceOver-Oberfläche. Der Export ist das Sprechbuch mit seinen Lerninhalten.
Entwürfe außerhalb der beiden Inhaltsdateien gehören erst nach ihrem Einbau dazu.

## Voraussetzungen

Python 3.10 oder neuer, `ffmpeg` und `ffprobe`. Die Python-Abhängigkeit ist nur `pyphen`
für die bestehende Fraktur-Zeichenabbildung. Es sind keine TTS-Schlüssel nötig.

```sh
python3 -m venv .venv
.venv/bin/pip install -r tools/requirements-narration.txt
.venv/bin/python tools/narration.py export
```

Bei bestehender Projekt-venv entfällt deren Neuanlage. `export` schreibt die Dateien im
Ordner `narration/` neu; die App-Texte und Audiodateien bleiben dabei unverändert.

## Dateien für die andere LLM

| Datei | Zweck |
|---|---|
| [`manifest.json`](../narration/manifest.json) | Vollständiger Vertrag: IDs, Text-Hashes, Segmente, Sprachen, Ziele, Tokens und Quellenabdeckung |
| [`texts.jsonl`](../narration/texts.jsonl) | Ein Auftrag pro Zeile für stapelweise Verarbeitung |
| [`TEXTS.md`](../narration/TEXTS.md) | Sprechtexte zum Lesen und Gegenhören |
| [`delivery-template.json`](../narration/delivery-template.json) | Kopf einer Rücklieferung; `recordings` durch tatsächliche Ergebnisse ergänzen |
| [`delivery.schema.json`](../narration/delivery.schema.json) | Maschinenlesbares Rückgabeformat |
| [`VERTONUNG_PROMPT.md`](VERTONUNG_PROMPT.md) | Kopierfertiger Arbeitsauftrag einschließlich Aussprache und Qualitätsprüfung |

Das Repository und die Übergabedateien sind öffentlich zugänglich. GitHub stellt große
JSON-Dateien eventuell nur zum Herunterladen bereit. Mit einem Clone oder „Code → Download ZIP“
erhält die andere LLM den vollständigen Bestand.

## Was die andere LLM zurückgibt

Ein Verzeichnis mit `delivery.json` und den darin referenzierten Audiodateien. Unterstützt
werden durch FFmpeg lesbare WAV-, MP3- oder M4A-Dateien mit genau einer Audiospur. Die Dateien
liegen innerhalb des Lieferverzeichnisses; relative Unterordner sind erlaubt.

```json
{
  "schema_version": 1,
  "manifest_sha256": "aus manifest.json übernehmen",
  "producer": {
    "provider": "tatsächlich verwendeter Dienst oder lokale Engine",
    "model": "tatsächliches Audiomodell",
    "voice": "verwendete Stimme oder Verweis auf Angaben je Aufnahme",
    "usage_rights": "Quelle/Angabe zu den Nutzungsbedingungen der Aufnahme"
  },
  "recordings": [
    {
      "job_id": "ID aus jobs[].id",
      "job_sha256": "Hash aus jobs[].sha256",
      "audio": "audio/datei.wav",
      "voice": "Charon für Deutsch; tatsächlich gewählte Muttersprach-Stimme für FR/EN",
      "words": [
        {"token_id": 0, "start_ms": 100, "end_ms": 420},
        {"token_id": 1, "start_ms": 460, "end_ms": 950}
      ]
    }
  ]
}
```

Die Beispielzeiten zeigen nur das Format. Jede echte Lieferung braucht gemessene Zeiten
aus genau ihrer Aufnahme. Der Importer akzeptiert keine Platzhalter und keine fehlenden Tokens.

Ein Token enthält den unveränderten Anzeigetext (`display`), einen Aussprachevorschlag
(`spoken`) und die Segment-/Zeichenposition. Die andere LLM liefert lediglich die Token-ID
und Anfang/Ende in **ganzen Millisekunden seit Dateibeginn**, einschließlich anfänglicher
Stille. Für „etc.“ kann ein Token mehrere gesprochene Wörter enthalten: Die Zeitspanne
umfasst dann das gesamte „et cetera“. Satzzeichen ohne eigenen Token brauchen keine Zeitmarke.

Token-IDs kommen genau einmal und in Exportreihenfolge vor. Zeitspannen sind positiv,
überschneiden sich nicht und liegen vollständig in der Aufnahme. Absatzpausen bleiben als
Zeitlücken erhalten. Wenn der Generator nur Satzzeiten oder gar keine Zeiten liefert, muss
die andere LLM eine **Wortausrichtung am fertigen Audio** durchführen und die Ergebnisse auf
die exportierten Tokens abbilden. Eine rechnerische Verteilung über die Audiodauer reicht nicht.

## Prüfen und einlesen

Zunächst kleine echte Hörproben aus Deutsch mit Charon, Französisch, Englisch, einer Abkürzung
und einem Fibel-Beispiel zurückliefern. Bereits freigegebene Proben brauchen keine Wiederholung.
Mario beurteilt noch offene Aussprache-/Fremdstimmenproben; Charon ist für Deutsch festgelegt.
Technische Teilpakete sind ausdrücklich möglich:

```sh
.venv/bin/python tools/narration.py validate \
  --delivery narration-incoming/probe/delivery.json --partial

.venv/bin/python tools/narration.py import \
  --delivery narration-incoming/probe/delivery.json --partial
```

Eine vollständige Lieferung lässt sich ohne `--partial` prüfen und importieren. Dann müssen
alle 1.204 Aufträge im Paket stehen. Auch nach mehreren Teilimporten sollte die andere LLM
eine vollständige `delivery.json` samt Dateien für diese Abschlussprüfung liefern.

```sh
.venv/bin/python tools/narration.py validate --delivery narration-incoming/gesamt/delivery.json
.venv/bin/python tools/narration.py import --delivery narration-incoming/gesamt/delivery.json
```

Der Importer prüft den aktuellen Quelltext gegen den Export, die IDs und Hashes, sämtliche
Token-Zeitspannen, Dateipfade und die Dekodierbarkeit des Audios. Er bereitet AAC/M4A mit
96 kbit/s, 44,1 kHz, mono vor und kontrolliert die Dauer erneut. `validate` verwirft diese
temporären Konvertierungen; es schreibt keine App-Dateien.

Erst nach erfolgreicher Prüfung des gesamten Pakets ersetzt `import` den Audioordner.
Die bisherige Fassung liegt unter `build/narration-backups/<Zeitstempel>/`, außerhalb der
App-Ressourcen. Dieser Ordner und
`narration-incoming/` sind von Git ausgeschlossen. Ein identischer erneuter Import ändert
keine Dateien und legt keine weitere Sicherung an. Quelltext oder Audio dürfen während des
Imports nicht durch eine zweite Sitzung bearbeitet werden; erkannte Änderungen brechen ab.

**Rücknahme:** Bei geschlossener Build-/App-Sitzung den aktuellen `Content/Audio`-Ordner
beiseite sichern und den im Importbericht genannten Sicherungsordner nach `Content/Audio`
zurückverschieben. Er enthält den vollständigen vorherigen Stand einschließlich Index.

## Verwendung in iOS

- Kapitel, Tafeln und Menüs behalten ihre bisherigen Dateinamen und ihren bestehenden Player.
- `LernStimme` und die Fibel suchen eine Aufnahme nach SHA-256 aus `Sprache + "\n" + exaktem Text`.
  Nur passende Texte werden abgespielt. Ohne passende, lesbare Aufnahme bleibt die Systemstimme verfügbar.
- `Content/Audio/narration-index.json` ordnet Texte einem Segment der Aufnahme zu. Daher kann
  auch eine vorhandene Kapitelaufnahme einen einzelnen Lerntext liefern.
- Sobald ergänzende Aufnahmen vorliegen, erscheint unter **Über das Buch → Weitere Hörtexte**
  eine durchsuchbare Liste. Dort sind auch Tabellenzellen, Antwortoptionen und Buchangaben hörbar,
  die im bisherigen Bildschirm keinen eigenen Vorleseknopf haben.
- Die gelbe Markierung nutzt die gelieferten Wortzeiten. Die andere LLM berechnet keine Fraktur-
  oder UTF-16-Positionen: Importer und App übernehmen diese Abbildung.

Ein Import verändert den lokalen Quellbestand für den **nächsten App-Build**. Bereits installierte
TestFlight-Apps laden keine neuen Dateien vom Server. Nach Import sind Build, Simulator-/Gerätetest
und ein beauftragter neuer TestFlight-Upload erforderlich.

`tools/build_audio.py` bleibt als frühere, an edge-tts gebundene Pipeline erhalten. Nach externem
Import nicht pauschal darüberlaufen lassen: Dieser Befehl kann die gelieferten Stimmen ersetzen.

## Prüfung dieser Schnittstelle

```sh
.venv/bin/python -m pytest tools/tests/test_narration.py -q
```

Die Importtests verwenden ausschließlich eine schon vorhandene Tafelaufnahme. Sie prüfen echte
Dekodierung/Konvertierung, Rücksicherung, wiederholten Import, Unicode-Zeichen und abgelehnte
Fehllieferungen. Swift-Tests prüfen Text-/Sprachbindung, Segmentwiedergabe, fehlende Metadaten und
Unicode-/Wortmarkierung. Der spezielle UI-Test benötigt einen isolierten Build mit Importfixture.
Die Tests ersetzen nicht Marios Hörprüfung der später von der anderen LLM erzeugten Aufnahmen.

Ergebnis der Implementierungsprüfung: [Prüfbericht mit Bildschirmnachweis](VERTONUNG_PRUEFUNG.md).
