"""Belege und Navigation der Lernredaktion prüfen; keine Audio-Neuerzeugung."""
import json
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from build_lernen import build, ROOT, K, TAFELN, MENU

class LernRedaktionTests(unittest.TestCase):
    def test_build_reproduzierbar(self):
        self.assertEqual(build(),json.loads((ROOT/'Content/lernen.json').read_text()))

    def test_alle_tourziele_und_quellen(self):
        c=build()
        def ziel(z):
            typ,id=z['art'],z['id']
            if typ=='kapitel': self.assertIn(z['seite'],[s['nr'] for s in K[id]['seiten']])
            elif typ=='tafel': self.assertIn(id,TAFELN)
            elif typ in ('menu','menuhilfe'): self.assertEqual(id,MENU)
            elif typ=='begriff': self.assertIn(id,[b['id'] for b in c['begriffe']])
            elif typ=='fragen': self.assertIn(id,[f['kapitel'] for f in c['fragen']])
            elif typ=='bild': self.assertIn(id,[f['id'] for f in c['bildaufgaben']])
            elif typ=='leseuebungen': self.assertIn(id,['gruppe','satz'])
            else: self.assertEqual(typ,'fibelQuiz')
        for group in ['begriffe','fragen','kontexte','leseuebungen','bildaufgaben','menufuehrer']:
            self.assertEqual(len(c[group]),len({x['id'] for x in c[group]}))
            for x in c[group]: ziel(x['quelle'])
        for t in c['touren']:
            for s in t['schritte']: ziel(s['ziel'])

    def test_fenster_liegen_im_bild(self):
        for a in build()['bildaufgaben']:
            self.assertTrue((ROOT/'Content/Images'/a['bild']).is_file())
            for o in a['optionen']:
                x,y,w,h=o['crop']
                self.assertGreater(w,0);self.assertGreater(h,0)
                self.assertGreaterEqual(x,0);self.assertGreaterEqual(y,0)
                self.assertLessEqual(x+w,1);self.assertLessEqual(y+h,1)

    def test_fibel_lautfehler_entfernt(self):
        fibel=json.loads((ROOT/'Content/content.json').read_text())['fibel']
        self.assertNotIn('Lies sie als zwei Laute',json.dumps(fibel,ensure_ascii=False))
        for u in build()['leseuebungen']:
            self.assertIn(u['neu'],u['quelle']['zitat'])
            self.assertEqual(len(u['map']),len(u['neu'])+1)
            self.assertEqual(u['map'][-1],len(u['alt']))
            self.assertEqual(u['map'],sorted(u['map']))

if __name__=='__main__': unittest.main()
