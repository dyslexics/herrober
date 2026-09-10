# Heutige Rechtschreibung in den Lesetexten

Auftrag von Mario am 10.09.2026: neue deutsche Rechtschreibung im Text, ausdrücklich nicht
in den Bildbeschreibungen; anschließend bestätigt: in beiden Schriftansichten.

`tools/build_content.py` modernisiert Kapiteltexte einschließlich Überschriften, Randtiteln,
Fußnoten, Listen und Tabellen sowie das Vorwort, den Über-Text und die Kapitelverweise im Inhaltsverzeichnis. Erst danach entsteht
die Frakturfassung. „Alt“ und „Neu“ bezeichnen weiterhin die Schriftart. Seitenzahlen,
Kapitel-IDs und der Lesefortschritt bleiben kompatibel.

`tools/rechtschreibung_woerter.json` enthält die einzeln geprüften Wortformen des Buches,
unter anderem Local → Lokal, Thür → Tür, Capitel → Kapitel, Compotteller → Kompottteller,
Stengel → Stängel in den vorkommenden Zusammensetzungen. `tools/rechtschreibung.py`
behandelt zusätzlich Wendungen wie „im Allgemeinen“ und „voneinander“. Es gibt keine
pauschale Ersetzung von c, th oder ß. Namen wie Heß und Scheichelbauer, Wörter wie
Thunfisch und Theater sowie französische Wendungen wie „à couvert“ und „le menu“ bleiben
erhalten. Österreichische Ausdrücke und die historische Aussage werden nicht umgeschrieben.

Die vollständigen Datenbereiche `tafeln`, `menus` und `fibel` müssen gegenüber Build 1
unverändert bleiben. Im Inhaltsverzeichnis bleiben Seitenzahlen, Reihenfolge und Titel zu
Bildtafeln/Menükarten unverändert; Kapitelüberschriften folgen der modernen Lesefassung. Auch die korrigierten historischen
Transkriptionen unter `tools/korrektur/` und die Originale unter `raw/` werden nicht geändert.

Die Kapitel-Audios werden mit derselben Stimme neu erzeugt, einschließlich Wortzeiten
und Zeichenbereichen in beiden Schriften. Der Audio-Cache prüft deshalb neben dem
gesprochenen Text auch den Anzeigetext und die Segmentpositionen: Gleiche Aussprache
allein erlaubt keine Wiederverwendung alter Zeichenbereiche.

Grundlage: [Rat für deutsche Rechtschreibung, Amtliches Regelwerk 2024](https://www.rechtschreibrat.com/regeln-und-woerterverzeichnis/).
Wortschatzprüfung zusätzlich mit dem [deutschen LibreOffice-Wörterbuch](https://github.com/LibreOffice/dictionaries/tree/master/de);
dessen Treffer sind Prüfhinweise, keine automatische Ersatzentscheidung. Fachbegriffe und
österreichische Formen werden dabei nicht allein wegen fehlender Wörterbucheinträge geändert.
