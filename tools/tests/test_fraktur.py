import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import pytest
from fraktur import frakturisieren, wort_frakturisieren, antiqua_bereiche

# Golden-Liste: Referenzen aus Titelblatt/Tafeln des Buches und Duden-Fraktursatz (Wikipedia „Langes s“)
GOLDEN = [
    ('Tisch', 'Tiſch'), ('Fisch', 'Fiſch'), ('Besteck', 'Beſteck'), ('Gast', 'Gaſt'), ('Gäste', 'Gäſte'),
    ('dass', 'daſs'), ('muss', 'muſs'), ('lässt', 'läſst'), ('Fluss', 'Fluſs'), ('Bewusstsein', 'Bewuſstſein'),
    ('Wasser', 'Waſſer'), ('Messer', 'Meſſer'), ('Aussicht', 'Ausſicht'), ('Ausschank', 'Ausſchank'),
    ('aussprechen', 'ausſprechen'), ('Häuschen', 'Häuschen'), ('Dienstag', 'Dienstag'), ('Donnerstag', 'Donnerstag'),
    ('Fenster', 'Fenſter'), ('Kunst', 'Kunſt'), ('Obst', 'Obſt'), ('Gasthaus', 'Gaſthaus'), ('Gastwirt', 'Gaſtwirt'),
    ('Ausdrücke', 'Ausdrücke'), ('Servierkunde', 'Servierkunde'), ('Speisenfolge', 'Speiſenfolge'),
    ('Speise', 'Speiſe'), ('Glas', 'Glas'), ('Gläser', 'Gläſer'), ('Glasschale', 'Glasſchale'), ('Eisschrank', 'Eisſchrank'),
    ('Reissuppe', 'Reisſuppe'), ('Preisliste', 'Preisliſte'), ('Festtafel', 'Feſttafel'), ('Restaurant', 'Reſtaurant'),
    ('Kellners', 'Kellners'), ('Gästen', 'Gäſten'), ('sie', 'ſie'), ('Sie', 'Sie'), ('so', 'ſo'), ('ist', 'iſt'),
    ('es', 'es'), ('uns', 'uns'), ('unser', 'unſer'), ('unsre', 'unſre'), ('besonders', 'beſonders'),
    ('Erbse', 'Erbſe'), ('Rätsel', 'Rätſel'), ('lesbar', 'lesbar'), ('Häuslein', 'Häuslein'), ('Arbeitsamt', 'Arbeitsamt'),
    ('Suppenschale', 'Suppenſchale'), ('Serviette', 'Serviette'), ('selbst', 'ſelbſt'), ('selbstverständlich', 'ſelbſtverſtändlich'),
    ('Ausputz', 'Ausputz'), ('Hausthür', 'Hausthür'), ('Taschen', 'Taſchen'), ('Mausefalle', 'Mauſefalle'),
    ('Wespe', 'Weſpe'), ('Knospe', 'Knoſpe'), ('erstaunen', 'erſtaunen'), ('Löffel', 'Löffel'), ('sausen', 'ſauſen'),
    ('Dessert', 'Deſſert'), ('Kaffeesieder', 'Kaffeeſieder'), ('Speisekarte', 'Speiſekarte'), ('Dienste', 'Dienſte'),
    ('Ausstattung', 'Ausſtattung'), ('Suppenlöffel', 'Suppenlöffel'), ('Hochzeitsdiner', 'Hochzeitsdiner'),
    ('Vorspeise', 'Vorſpeiſe'), ('Jahrestag', 'Jahrestag'), ('Salzfass', 'Salzfaſs'), ('Fässer', 'Fäſſer'),
    ('Mehlspeise', 'Mehlſpeiſe'), ('Weisswein', 'Weiſswein'), ('Kalbsschlegel', 'Kalbsſchlegel'), ('Speisesaal', 'Speiſeſaal'), ('Hausschuh', 'Hausſchuh'), ('Weinglas', 'Weinglas'), ('Weingläser', 'Weingläſer'), ('Sauciere', 'Sauciere'),
]


@pytest.mark.parametrize('neu,alt', GOLDEN)
def test_golden(neu, alt):
    assert wort_frakturisieren(neu) == alt


def test_laenge_bleibt_je_wort():
    for neu, _ in GOLDEN:
        assert len(wort_frakturisieren(neu)) == len(neu)


def test_etc_wird_rc_und_map_stimmt():
    neu = 'Bankett, Hochzeitsdiner etc. sind teuer.'
    r = frakturisieren(neu)
    assert 'ꝛc.' in r.alt and 'etc.' not in r.alt
    assert len(r.map) == len(neu) + 1 and r.map[-1] == len(r.alt)
    # Wortbereich "sind" (neu) zeigt in alt auf "ſind"
    a = neu.index('sind'); e = a + 4
    assert r.alt[r.map[a]:r.map[e]] == 'ſind'
    # Bereich von "etc." zeigt auf "ꝛc."
    a = neu.index('etc.'); e = a + 4
    assert r.alt[r.map[a]:r.map[e]] == 'ꝛc.'


def test_map_ist_monoton_und_deckt_alle_zeichen():
    neu = 'Tritt ein Gast in das Local, so haben ihn die Kellner zu begrüßen; „Guten Tag“ etc.'
    r = frakturisieren(neu)
    assert all(r.map[i] <= r.map[i + 1] for i in range(len(neu)))
    assert r.alt[r.map[neu.index('Gast')]:r.map[neu.index('Gast') + 4]] == 'Gaſt'
    assert r.alt[r.map[neu.index('Local')]:r.map[neu.index('Local') + 5]] == 'Local'


def test_antiqua_woerter_bleiben_und_werden_gemeldet():
    neu = 'Das Menu besteht aus Consommé und Dessert.'
    ranges = antiqua_bereiche(neu)
    worte = [neu[a:e] for a, e in ranges]
    assert 'Menu' in worte and 'Consommé' in worte and 'Dessert' not in worte
    r = frakturisieren(neu)
    assert 'Menu' in r.alt and 'Conſommé' not in r.alt and 'beſteht' in r.alt and 'Deſſert' in r.alt
    assert [r.alt[a:e] for a, e in r.antiqua] == ['Menu', 'Consommé']


def test_grossbuchstaben_und_satzzeichen_unveraendert():
    neu = 'SUPPE. „Ergebenster Diener“ — 2 fl. 50 kr.'
    r = frakturisieren(neu)
    assert r.alt.startswith('SUPPE. „Ergebenſter Diener“')
