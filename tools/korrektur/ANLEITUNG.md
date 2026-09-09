# Anleitung: OCR-Korrektur „Servierkunde“ (Wien 1899)

Du korrigierst eine OCR-Arbeitsfassung eines Fraktur-Buches von 1899. Ziel ist der **originalgetreue Text von 1899**, nicht ein moderner Text. Die Korrektur wird später vorgelesen (TTS) und in Fraktur gesetzt, jeder Restfehler ist hörbar und sichtbar.

## Eingabe / Ausgabe

- Eingabe: `tools/korrektur/raw/<NN>_<name>.md` (nur lesen).
- Ausgabe: `tools/korrektur/<NN>_<name>.md` (gleicher Dateiname, mit dem Write-Tool schreiben).
- Zusätzlich am Ende deiner Antwort: eine kurze Liste der 10 wichtigsten Unsicherheiten (Seite + Wort), sonst nichts.

## Struktur, die du EXAKT unverändert lässt

- Zeilen, die mit `## `, `### `, `<a id=`, `*Quelle:` oder `![` beginnen: unverändert übernehmen, Reihenfolge behalten. Keine Seite weglassen, keine hinzufügen.
- Leerzeilen zwischen Blöcken behalten (ein Block = ein Absatz).

## Was du korrigierst (nur OCR-Fehler)

Typische Fraktur-OCR-Fehler, an denen du sie erkennst:
- `j` statt `s` (langes ſ): „Tijch“ → „Tisch“, „Diejer“ → „Dieser“, „ijt“ → „ist“, „ebenjo“ → „ebenso“, „wünjchen“ → „wünschen“
- `ß` statt `tz`: „Plaß“ → „Platz“, „leßteren“ → „letzteren“, „vorgeseßt“ → „vorgesetzt“, „besißen“ → „besitzen“, „seßt“ → „setzt“ (aber echtes ß bleibt: „Gruß“, „größer“, „muß“ ist NICHT im Buch, das Buch schreibt „muss“)
- `z` statt `tz`: „niedersezen“ → „niedersetzen“, „Fußspizen“ → „Fußspitzen“
- `f` statt `k`, `k` statt `f`: „befannteren“ → „bekannteren“, „filb.“ → „silb.“
- `B` statt `P`, `U` statt `A`, `IH` statt „Ich“, `sig` statt „sich“, `dais` statt „dass“, `fie` statt „sie“, `auc;` statt „auch“
- `&gt;` / `&lt;` (HTML-Reste) stehen fast immer für „ck“: „Kleiderstoc&gt;“ → „Kleiderstock“, „Ausdrüe“ → „Ausdrücke“
- „2c.“ ist die Fraktur-Abkürzung „ꝛc.“ = „etc.“ → schreibe **„etc.“**
- Zeilenumbruch-Reste: „Feldmarschall - Lieutenant“ → „Feldmarschall-Lieutenant“; „Special- Lehr- und Hilfsbücher“ bleibt (echte Ergänzungsstriche)
- Zahlen-/Zeichensalat innerhalb von Fließtext (z. B. „vais 9-r Gäste“, „59 BEEREN“, „3%) 3, B,“): aus dem Kontext rekonstruieren; wenn nicht möglich, weglassen und die Stelle mit `⟨?⟩` markieren.
- Anführungszeichen einheitlich „…“ (deutsch unten/oben), Apostroph ’ ist ok.

## Was du NICHT änderst (Orthographie 1899 bleibt)

Diese Schreibweisen sind richtig und bleiben: Thür, Local/Locale, Capitel, Couvert, Doctor, Officier, Lieutenant, Principal, Special, nothwendig, Räthe, Muth, Werth, Theil, Vortheil, reflectieren, Clientel, Nuancierung, Etiquette, Cognac, Liqueur, Sauce, Bouillon, Menu, Dejeuner/Déjeuner, Diner/Dîner, Souper, Buffet, Banquet, Jänner, Kaffeesieder, Kellnerei, Speisenfolge, giebt, Litre, Gulden (fl.), Kreuzer (kr.), „dass/muss/lässt“ (Heyse-Schreibung), Excellenz, Chargen, Präcision, Toilette, Servietten, ss statt ß nach kurzem Vokal.
Regel: Wenn ein Wort eine plausible Schreibweise von 1899 ist, bleibt es. Nur wenn es kein deutsches Wort (auch kein altes) ergibt, ist es ein OCR-Fehler.
Nichts kürzen, nichts ergänzen, nichts umformulieren, keine Kommentare in den Text.

## Randtitel (Marginalien)

Das Original hat am Seitenrand kurze Stichworte („Begrüßung der Gäste“, „Titulaturen.“, „Reinigung der Gläser“). Die OCR hat sie in den Fließtext gemischt (z. B. „so haben ihn die anwesenden **Begrüßung** Kellner stehend zu begrüßen … vais 9-r Gäste“ = Randtitel „Begrüßung der Gäste“) oder als eigene kurze Zeilen abgelegt („Instand-“ / „haltung des“).
→ Randtitel aus dem Fließtext herauslösen und als eigene Zeile **vor** dem zugehörigen Absatz schreiben, Format: `@@ Begrüßung der Gäste`
→ Nur wenn der Randtitel klar erkennbar ist. Sonst die Fragmente entfernen und `⟨?⟩` am Absatzanfang setzen.

## Gedruckte Überschriften

Die erste Zeile eines Kapitels wiederholt den Kapiteltitel („1. Capitel. Über das Verhalten des Kellners im Dienste,“) → als `#### 1. Capitel. Über das Verhalten des Kellners im Dienste.` schreiben (Level-4-Überschrift, Komma am Ende zu Punkt).
Zwischenüberschriften im Text („a) Landarmee:“, „Titulaturen.“ als eigene Zeile) → ebenfalls `#### …`.

## Fußnoten

Fußnoten stehen am Seitenende und beginnen mit `*)` oder `**)`. Sie bleiben eigene Absätze am Ende der Seite, beginnend mit `*) ` bzw. `**) `. Die Verweise im Text (`*)`, `**)`) bleiben stehen. OCR-Varianten wie „3%)“, „**)“ vereinheitlichen.

## Tabellen und Listen

- Markdown-Tabellen (`|`) und Listen (`- `, `1. `) behalten; Inhalt korrigieren.
- Zerstörte Tabellen (z. B. Militär-Chargen mit Sternen) nur rekonstruieren, wenn der Inhalt aus dem Kontext sicher ist; sonst als Absatz mit `⟨?⟩` belassen.

## Seitenumbruch mitten im Wort

Endet eine Seite mit einem Wortfragment („Instand-“) und die nächste beginnt mit dem Rest („haltung“), dann das Wort **auf der früheren Seite vervollständigen** und das Fragment auf der späteren Seite entfernen.

## Unsicherheit

Unsichere Wörter so markieren: `⟨Wort?⟩`. Lieber markieren als raten. Aber: eindeutige OCR-Muster (j→s, ß→tz, &gt;→ck) sind keine Unsicherheit, die korrigierst du ohne Markierung.
