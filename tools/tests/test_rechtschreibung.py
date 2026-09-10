import json
import sys
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from rechtschreibung import modernisieren
from build_content import seiten_parsen
import build_audio


def test_lesetext_in_beiden_schriften_bildbeschreibung_ausgenommen():
    markdown = '### Seite 5\n\nDie Thür im Local. Im allgemeinen sind Compotteller nöthig.\n'
    modern = seiten_parsen(markdown, modern=True)[0]['bloecke'][0]
    assert modern['neu'] == 'Die Tür im Lokal. Im Allgemeinen sind Kompottteller nötig.'
    assert modern['alt'].replace('ſ', 's') == modern['neu']
    original = seiten_parsen(markdown)[0]['bloecke'][0]
    assert 'Thür im Local' in original['neu']
    assert 'Thür im Local' in original['alt']


def test_keine_pauschale_ersetzung_von_namen_und_fremdwoertern():
    text = 'Heß, Scheichelbauer, Thunfisch, Theater, Absinth, à couvert, le menu, Menu du Buffet, Cognac.'
    assert modernisieren(text) == text
    assert modernisieren('Couvert und Menu; Straße, muss, dass.') == 'Kuvert und Menü; Straße, muss, dass.'
    assert modernisieren('von Liqueurs und Cognac') == 'von Likören und Cognac'


def test_tabellen_und_listen_modernisiert():
    m = '### Seite 12\n\n| Classe | Officiere |\n\n- Nothwendige Eintheilung\n'
    blocks = seiten_parsen(m, modern=True)[0]['bloecke']
    assert blocks[0]['zeilen'] == [['Klasse', 'Offiziere']]
    assert blocks[1]['items'][0]['neu'] == 'Notwendige Einteilung'


def test_audio_cache_beruecksichtigt_anzeigetext(tmp_path):
    # Local und Lokal werden identisch gesprochen, haben aber verschiedene Anzeigetexte.
    segs = [(0, 0, -1, 'Lokal', '5')]
    voice = 'de-AT-JonasNeural'
    cached = {'hash': build_audio.hash_von(build_audio.gesprochener_text(segs), voice),
              'segments': [{'seite': 0, 'block': 0, 'item': -1, 'text': 'Local', 'nr': '5'}]}
    (tmp_path / 'sample.json').write_text(json.dumps(cached))
    (tmp_path / 'sample.m4a').write_bytes(b'cached audio')
    with patch.object(build_audio, 'OUT', str(tmp_path)), \
         patch.object(build_audio, 'synth', side_effect=RuntimeError('fresh synthesis needed')):
        import pytest
        with pytest.raises(RuntimeError, match='fresh synthesis needed'):
            build_audio.vertonen('sample', segs, voice)
