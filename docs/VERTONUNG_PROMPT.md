# Arbeitsauftrag für die andere LLM

Den folgenden Text zusammen mit dem Repository oder dessen Ordner `narration/` übergeben.

---

Du übernimmst die vollständige Vertonung der iOS-App **Herr Ober! – Servierkunde 1899**.
Die App und ihre Lerninhalte sind fertig. Du sollst mit einem geeigneten Audiowerkzeug
Aufnahmen herstellen und in das vorbereitete Format zurückgeben. Die Vorbereitung dieser
Schnittstelle hat keine neuen Aufnahmen erzeugt.

Lies zuerst `docs/VERTONUNG.md`, `narration/manifest.json` und
`narration/delivery.schema.json`. Wenn du nur den Übergabeordner erhalten hast, verwende
die darin beigelegten gleichnamigen Dokumente. Das Manifest ist die verbindliche Auftragsliste.
Lade das große Manifest mit einem Programm, zum Beispiel `json.load()` in Python. Gib jeweils
nur den aktuellen Auftrag oder eine knappe Übersicht in deinen LLM-Kontext; die vollständigen
Wortpositionen aller Aufträge müssen dort nicht gleichzeitig stehen.

## Ergebnis

Liefere ein Verzeichnis mit **delivery.json**, den darin genannten Audiodateien und einem
kurzen Prüfbericht. Bearbeite sämtliche `jobs` des Manifests. Stelle zusätzlich eine
vollständige Abschlusslieferung bereit, auch wenn du während der Arbeit Teilpakete lieferst.
Halte IDs und Text-Hashes unverändert. Melde fehlende Dateien und nicht ausführbare Aufträge
offen; gib keine unvollständige Sammlung als fertig aus.

## Ablauf

1. Prüfe, ob du tatsächlich Audiodateien erzeugen und speichern kannst. Wenn dir ein
   Audiowerkzeug fehlt, nenne die benötigte Fähigkeit. Text oder eine Beschreibung einer
   Stimme sind keine Audiodatei.
2. Nutze Marios verfügbare und freigegebene Sprachwerkzeuge. Falls Stimme, Zugang oder
   Kostenrahmen für deinen Dienst fehlen, kläre das mit Mario. Verrate keine Schlüssel und
   schreibe sie weder in das Repository noch in Lieferdateien.
3. Lies die Aufträge aus `manifest.json`; `texts.jsonl` eignet sich zur Stapelverarbeitung,
   `TEXTS.md` zur Gegenprüfung. Die Abschnitte in `segments` bilden die Lesereihenfolge.
4. Erzeuge zuerst vier kurze, echte Proben: einen deutschen Absatz, einen französischen
   Menütext, eine Abkürzung wie „etc.“ und eine Fibel-Stelle mit langem ſ. Lass Mario die
   Stimme und Aussprache beurteilen, bevor du die vollständige Sammlung erzeugst.
5. Bearbeite die Aufträge danach in überschaubaren Paketen. Speichere deinen Fortschritt
   anhand der Job-ID, ihres Hashs und des Dateihashs. Ein fehlgeschlagener Auftrag darf
   bereits fertige Aufnahmen nicht überschreiben. Nutze geprüfte Ergebnisse bei Fortsetzung erneut.
6. Erzeuge echte Wortzeitmarken für genau das fertige Audio, einschließlich Pausen und
   Anfangsstille. Verwende die Grenzen des Generators oder führe eine Wortausrichtung am
   fertigen Audio durch. Ordne jede exportierte Token-ID genau einmal zu.
7. Prüfe die Lieferung mit dem beigefügten Importer. Liefere am Ende alle Dateien sowie
   Anzahl, Sprachen, verwendete Stimmen/Modelle, Audiodauer und Prüfergebnis. Überlasse Mario
   die Prüfung der späteren App-Fassung; veröffentliche oder lade nichts ohne entsprechenden Auftrag hoch.

## Text und Aussprache

- Bewahre die Buch- und Lerninhalte. Übersetze, vereinfache, kürze oder ergänze sie nicht.
  Moderne deutsche Rechtschreibung im Lesetext ist in beiden Schriftansichten gewollt.
  Bildbeschreibungen und Menükarten behalten ihre historische Schreibweise.
- Verwende die Sprache aus `language`: `de-AT`, `fr-FR` oder `en-US`. Deutsche Erklärungen zu
  französischen Menüs bleiben deutsch; die französischen Zitate sprichst du französisch.
- Sprich Deutsch ruhig, klar und natürlich, mit gut verständlicher österreichischer Aussprache
  sofern verfügbar. Wähle passende Muttersprachlichkeit für Französisch und Englisch. Stimme
  und Sprechweise sollen innerhalb derselben Sprache zusammenpassen. Keine Musik, Effekte,
  Begrüßungen, Abschlussfloskeln oder zusätzlichen gesprochenen Überschriften.
- `spoken_text` und `tokens[].spoken` enthalten Aussprachevorschläge der vorhandenen Pipeline.
  Lies Fraktur-ſ als s, ꝛc. als „et cetera“, Abkürzungen und Zahlen im Zusammenhang.
  Buchstabennamen sind in der Fibel von Lauten zu unterscheiden. Einzelnes „ſ“ bezeichnet s;
  die exportierte Alphabet-Einheit „langes s“ soll genau so gesprochen werden.
- Prüfe Eigennamen wie Heß, Scheichelbauer, Sirowy und Czjžek sowie französische Speisennamen.
  Die Aussprachevorschläge sind keine zusätzlichen Buchinhalte. Falls ein Vorschlag falsch
  oder unklar ist, protokolliere deine Aussprachekorrektur; der Anzeigetext und seine Token-IDs
  bleiben unverändert. Ordne die korrigierte Aussprache weiterhin denselben Anzeigetokens zu.
- Bei „etc.“ kann ein Anzeigetoken mehrere gesprochene Wörter umfassen. Liefere eine gemeinsame
  Zeitspanne vom Anfang bis zum Ende dieser Wörter. Schätze einzelne Wortzeiten nicht aus
  Satzlänge, Zeichenanzahl oder Gesamtdauer.
- Absichtlich falsche Fibel-Antworten und interne OCR-Unsicherheitsnotizen sind ausgeschlossen.
  Bei Verständnisfragen sind die Antwortoptionen dagegen Teil des Textbestands; sprich keine
  ungefragte Auflösung dazu. Die Erklärung liegt als eigener Auftrag vor.

## Liefervertrag

Übernimm `manifest_sha256` aus dem Manifest und `job_sha256` aus dem jeweiligen Auftrag.
Für jede Aufnahme liefere `job_id`, einen relativen Pfad `audio` und `words`:

```json
{"token_id": 0, "start_ms": 100, "end_ms": 420}
```

Diese Zahlen sind nur ein Formatbeispiel. Deine tatsächlichen Zahlen stammen aus der
Audioausrichtung. Es sind ganze Millisekunden seit Dateibeginn. Tokens stehen in der
Manifestreihenfolge, mit positiver Dauer, ohne Überschneidung und vollständig innerhalb
der Audiodatei. Liefere alle Tokens, auch einzelne Buchstaben, Ziffern und Bruchzeichen.

Nutze WAV, MP3 oder M4A mit einer Audiospur. Bewahre die erzeugte Qualität in deiner Lieferung;
der Importer erstellt das App-Format. Lege Modell, Anbieter, Stimme und die maßgeblichen
Nutzungsangaben in `producer` offen. Abweichende Stimmen je Datei gehören zusätzlich in
`recordings[].voice`. Keine künstlichen oder erfundenen Herkunftsangaben.

## Befehle zur Prüfung

Im Repository:

```sh
.venv/bin/python tools/narration.py validate --delivery PFAD/delivery.json --partial
```

Für die vollständige Abschlusslieferung ohne `--partial`:

```sh
.venv/bin/python tools/narration.py validate --delivery PFAD/delivery.json
```

Der Importer lehnt einen veralteten Export ab. Ändert sich der App-Text während deiner Arbeit,
gleiche ihn mit Mario ab und exportiere neu. Schreibe keine Hashes um, um die Prüfung zu umgehen.

Wenn Mario auch das Einlesen beauftragt hat:

```sh
.venv/bin/python tools/narration.py import --delivery PFAD/delivery.json
```

Dieser Befehl übernimmt die geprüften Aufnahmen samt Wortmarken und legt eine Sicherung an.
Danach braucht die App einen neuen Build. Das Hochladen zu GitHub, TestFlight oder in den
App Store ist ein eigener, konkret beauftragter Schritt.

Zum Abschluss: Übergabeverzeichnis, Zahl der fertigen/fehlenden Aufträge, Prüfbefehl mit
Ergebnis, offene Aussprachefragen und Marios nächste Handlung nennen.
