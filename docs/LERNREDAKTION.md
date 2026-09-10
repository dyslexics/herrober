# Lernbereich · Build 3

Umsetzung von Marios Auftrag vom 10.09.2026 auf Grundlage der Inhaltsberatung im Henry Vault.

## Inhalt und Bedienung

- 40 Begriffserklärungen mit historischen und aktuellen Wortformen, Suche, Merkliste, Aussprache und Buch-/Tafelverweisen. Die Wort-Lupe im Kapitel zeigt passende Erklärungen direkt an. Mehrteilige Fremdwörter werden nur mit passendem Satzkontext zugeordnet.
- Drei Touren: erste Schicht (mit Gedeck), Johann-Strauss-Menü und Vorbereitung eines Festessens. Jede Station öffnet vorhandene Buchinhalte oder eine Übung; man kehrt zur Tour zurück und markiert die Station selbst als erledigt.
- 30 Fragen, je drei für die zehn Hauptkapitel. Jede Antwort erhält eine Erklärung und eine verlinkte Buchstelle. Unzutreffend beantwortete Fragen bleiben bis zur richtigen Wiederholung in „Noch einmal ansehen“.
- Drei Bildaufgaben: Fischmesser, Traubenschere und drei Positionen eines vereinfachten Gedecks. Keine reine Ziehbedienung: Gegenstände lassen sich durch Antippen auswählen und platzieren. Die Bilderkennungsaufgaben bieten zusätzlich Formbeschreibungen für VoiceOver.
- Ein Leseschlüssel zum Johann-Strauss-Menü mit zehn Abschnitten. Kartenzeilen werden direkt aus der vorhandenen Transkription übernommen; französische Zeilen können mit französischer Systemstimme angehört werden.
- Sechs Wortgruppen und sechs echte Buchsätze erweitern die vorhandene Fibel. Erst Fraktur lesen, dann neue Schrift aufdecken, anhören und bei Bedarf zur Buchstelle wechseln. Die Zeitmarkierung wird über die Fraktur-Zeichenabbildung umgerechnet, auch bei `etc.` → `ꝛc.`.
- Sechs Einordnungen zu Rangordnung, Arbeitsvorbereitung, Mahlzeiten, Karten, Festtafeln und Zimmerservice.
- Das originale Appsthrum-Banner mit sichtbarem Link steht am Ende von „Über das Buch“ und unter „Nach einer Idee von Rainer Ternik“ in den Einstellungen.

## Redaktion und Quellen

`tools/lernredaktion.py` enthält die neuen Begriffserklärungen, Fragen und Einordnungen. `tools/build_lernen.py` löst die Belege gegen `Content/content.json` auf und erzeugt `Content/lernen.json`. Der Build bricht bei fehlenden Textankern ab. Übungen und Touren führen über stabile IDs zu den vorhandenen Seiten, Tafeln und Karten.

Die Kapiteltranskription, Tafelbeschriftungen, Originalbilder und bisherigen Audios werden nicht neu erzeugt. In `tools/fibel.json` wurden die Verwechslung von Buchstaben und Lauten sowie ungenaue s-Merksätze korrigiert. Beide Schriftansichten des Lesetexts behalten die von Mario bestätigte heutige Rechtschreibung.

Die Redaktion ist in der App als „Heute erklärt“ gekennzeichnet. Das neue Glossar ist keine Rekonstruktion des fehlenden Fachwortanhangs S. 179–181. Original-PDFs waren bei dieser Arbeit weiterhin nicht verfügbar. Quellenbelege sind deshalb Belege der bereits gebauten Buchfassung; eine erneute Prüfung aller Textstellen gegen die fehlenden Scans ist damit nicht behauptet. Die dokumentierten unsicheren Tabellen und Zahlen wurden nicht als Fragenlösungen verwendet.

Die Bildfenster auf Tafel 10 und 19 wurden an den vorhandenen Bildern geprüft. Sie werden ausschließlich im UI ausgeschnitten. Tafel 42 bleibt vollständig erhalten: Die gedruckte Beschriftung nennt fünf Gläser; „Bier Glas“ ist eine handschriftliche Ergänzung. Die Gedeck-Aufgabe beschränkt sich ausdrücklich auf drei Besteckpositionen.

Menüerklärungen beschreiben Namen und Reihenfolge, ohne eine historische Zutatenliste oder Gästeliste zu erfinden. Zusätzliche Wortbelege:

- [Fogas / Zander · Treccani](https://www.treccani.it/enciclopedia/sandra_%28Enciclopedia-Italiana%29/)
- [Chapon · Académie française](https://www.dictionnaire-academie.fr/article/A9C1642)
- [Buchstabenfolgen und Laute · IDS](https://grammis.ids-mannheim.de/rechtschreibwortschatz/text/6348)

Das unveränderte Markenmotiv stammt aus `https://appsthrum.com/assets/banner.webp`, am 10.09.2026 mit HTTP 200 geladen und visuell geprüft. Nur das Dateiformat wurde für den Asset-Katalog von WebP nach PNG umgewandelt. Ziel beider Links: `https://appsthrum.com`.

## Speicherung und Vorlesen

`progress.v1` bleibt als bestehendes Lesestandsformat erhalten. `lernen.v1` speichert getrennt gemerkte Begriffe, beantwortete und zu wiederholende Fragen, Tourstationen und Übungen. Kein Konto und kein Server erforderlich. Die vorhandene Zurücksetzen-Funktion benennt und löscht beide Bereiche.

Die neuen Inhalte verwenden `AVSpeechSynthesizer` mit der installierten deutschen bzw. französischen Stimme. Pro Lernansicht läuft ein Sprecher; ein Zielwechsel stoppt ihn. Die bestehenden Buchaufnahmen und deren Wortzeiten bleiben erhalten. Die Systemstimme kann je nach Gerät anders klingen.

## Prüfen und Bauen

```sh
.venv/bin/python tools/build_content.py
.venv/bin/python tools/build_lernen.py
.venv/bin/python -m pytest tools/tests -q
bash tools/sync.sh
```

Native Prüfungen: `HerrOberTests`, `LernenTests`, `HerrOberUITests` und `LernenUITests` auf Mac Studio. Der Testbestand prüft Inhalte und Verweise, Beibehaltung des Lesestands, Wiederholung, Bildzuordnung, echte UI-Navigation, Quellen aus der Wort-Lupe, Merkliste, Tourfortschritt, Schriftvergleich sowie beide Markenverweise. Ergebnisse und Screenshots liegen lokal unter `build/learning-*`; der abschließende Prüfbericht ergänzt die konkreten Ergebnisse.

Ein signiertes Archiv kann anschließend mit `tools/mac_archive.sh 3` erstellt und exportiert werden. Dieses Skript lädt nichts zu App Store Connect hoch.
