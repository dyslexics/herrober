import XCTest
@testable import HerrOber

final class HerrOberTests: XCTestCase {
    let repo = ContentRepository(bundle: Bundle(for: ContentRepositoryMarker.self).appBundle)

    func testContentLaedt() {
        XCTAssertEqual(repo.bibliothek.version, 1)
        XCTAssertEqual(repo.kapitel.count, 12, "Einleitung, 10 Capitel, Couvertpreise")
        XCTAssertGreaterThanOrEqual(repo.alleTafeln.count, 53)
        XCTAssertGreaterThanOrEqual(repo.alleKarten.count, 14)
        XCTAssertNotNil(repo.bibliothek.fibel)
        XCTAssertFalse(repo.bibliothek.ueber.isEmpty)
        XCTAssertGreaterThan(repo.bibliothek.inhaltsverzeichnis.count, 100)
    }

    func testWarumKapitelVollstaendig() {
        let w = repo.bibliothek.warum ?? []
        XCTAssertGreaterThanOrEqual(w.count, 30, "Titel, acht Abschnitte und ihre Absätze")
        XCTAssertEqual(w.first?.typ, "ueberschrift")
        XCTAssertEqual(w.first?.ebene, 1)
        XCTAssertTrue(w.first?.neu?.contains("Legasthenieverband") ?? false)
        XCTAssertEqual(w.filter { $0.typ == "ueberschrift" && $0.ebene == 2 }.count, 8, "acht Zwischenüberschriften")
        for b in w {
            XCTAssertNotNil(b.neu); XCTAssertNotNil(b.alt)
            XCTAssertFalse(b.neu!.contains("Couvert"), "Wortformen wie im Lesetext (Kuvert)")
        }
        XCTAssertTrue(w.last?.neu?.contains("warum wir dieses Buch gemacht haben") ?? false)
        XCTAssertTrue(w.contains { $0.neu?.contains("legasthenietrainer.com") ?? false })
    }

    func testSeitenfolgeLueckenlos() {
        var erwartet = 5
        for k in repo.kapitel {
            for s in k.seiten {
                guard let n = Int(s.nr) else { continue }
                XCTAssertEqual(n, erwartet, "\(k.slug): Seite \(s.nr) statt \(erwartet)")
                erwartet = n + 1
            }
        }
        XCTAssertEqual(erwartet, 81, "Text endet mit Seite 80 (Couvertpreise)")
    }

    func testJederTextblockHatAltUndNeuUndKeineSteuerzeichen() {
        for k in repo.kapitel {
            for s in k.seiten {
                for b in s.bloecke {
                    let texte: [Block] = b.typ == "liste" ? (b.items ?? []) : [b]
                    for t in texte where t.typ != "tabelle" {
                        guard let neu = t.neu, let alt = t.alt else { XCTFail("\(k.slug) S. \(s.nr): Block ohne Text"); continue }
                        XCTAssertFalse(neu.isEmpty)
                        XCTAssertEqual(neu.count, neu.unicodeScalars.count, "Grapheme ≠ Codepoints: \(neu.prefix(40))")
                        XCTAssertEqual(alt.count, alt.unicodeScalars.count)
                        XCTAssertFalse(neu.contains("⟨") || neu.contains("⟩"), "Unsicherheitsmarker im Text: \(neu.prefix(60))")
                        for r in t.antiquaBereiche { XCTAssertLessThanOrEqual(r.upperBound, alt.count) }
                    }
                }
            }
        }
    }

    func testFontsGeladen() {
        for name in [Schrift.frakturName, Schrift.frakturFettName, Schrift.antiquaName, Schrift.antiquaFettName] {
            XCTAssertNotNil(UIFont(name: name, size: 20), "Font fehlt: \(name)")
        }
    }

    func testAlleBilderVorhanden() {
        XCTAssertNotNil(repo.bild(repo.buch.einband))
        XCTAssertNotNil(repo.bild(repo.buch.titelblatt))
        for t in repo.alleTafeln {
            XCTAssertNotNil(repo.bild(t.bild), "Tafel \(t.nr): \(t.bild)")
            XCTAssertNotNil(repo.thumb(t.bild), "Thumb Tafel \(t.nr)")
            XCTAssertNotNil(repo.original(t.bild), "Original Tafel \(t.nr)")
            for d in t.details { XCTAssertNotNil(repo.bild(d.bild), "Detail \(d.bild)") }
        }
        for k in repo.alleKarten { XCTAssertNotNil(repo.bild(k.bild), k.bild) }
    }

    func testAudioIndexUndWortzeiten() {
        for k in repo.kapitel {
            let teile = repo.audioTeile(k)
            XCTAssertFalse(teile.isEmpty, "kein Audio für \(k.slug)")
            for t in teile {
                XCTAssertNotNil(repo.audioURL(t.stem), t.stem)
                guard let d = repo.vorleseDaten(t.stem) else { XCTFail("Wortzeiten fehlen: \(t.stem)"); continue }
                XCTAssertFalse(d.words.isEmpty)
                XCTAssertLessThan(d.words[0].t, 500, "\(t.stem): erstes Wort spät")
                for w in d.words {
                    let seg = d.segments[w.s]
                    XCTAssertTrue(k.seiten.indices.contains(seg.seite), t.stem)
                    let block = k.seiten[seg.seite].bloecke[seg.block]
                    let quelle = seg.item >= 0 ? (block.items ?? [])[seg.item] : block
                    XCTAssertLessThanOrEqual(w.e, quelle.neu?.count ?? 0, "\(t.stem): Bereich neu außerhalb")
                    if let ae = w.ae { XCTAssertLessThanOrEqual(ae, quelle.alt?.count ?? 0, "\(t.stem): Bereich alt außerhalb") }
                    XCTAssertEqual(seg.text, quelle.neu, "\(t.stem): Segmenttext ≠ Blocktext")
                }
            }
        }
        for t in repo.alleTafeln {
            XCTAssertNotNil(repo.audioIndex.tafeln[t.nr], "kein Audio für Tafel \(t.nr)")
        }
    }

    func testFrakturTitelHilfe() {
        XCTAssertEqual(Fraktur.titel("Die Festtafel"), "Die Feſttafel")
        XCTAssertEqual(Fraktur.titel("Das Servieren der Getränke etc."), "Das Servieren der Getränke ꝛc.")
        XCTAssertEqual(Fraktur.entfrakturisieren("Gaſt ꝛc."), "Gast etc.")
        let t = "Tritt ein Gaſt in das Local."
        let r = Fraktur.wortBereich(in: t, um: 11)!
        XCTAssertEqual(String(t[r]), "Gaſt")
    }

    func testProgressStore() {
        let d = UserDefaults(suiteName: "test.progress")!
        d.removePersistentDomain(forName: "test.progress")
        let p = ProgressStore(defaults: d)
        let k = repo.kapitel[1]
        p.position(k, seite: k.seiten[0].nr)
        XCTAssertEqual(p.gelesen(in: k), 1)
        XCTAssertEqual(p.weiterlesen(repo)?.0.slug, k.slug)
        p.kapitelGelesen(k)
        XCTAssertTrue(ProgressStore(defaults: d).istGelesen(k))
    }

    func testStringsVollstaendig() {
        for key in L10n.de.keys { XCTAssertNotNil(L10n.en[key], "EN fehlt: \(key)") }
        for key in L10n.en.keys { XCTAssertNotNil(L10n.de[key], "DE fehlt: \(key)") }
    }

    func testZoomNachGroessenwechselPasstBildEin() {
        let scroll = ZoomScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        let coordinator = ZoomBild.Coordinator()
        scroll.delegate = coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 5
        scroll.addSubview(scroll.imageView)
        scroll.layoutIfNeeded()
        scroll.setZoomScale(3, animated: false)
        XCTAssertEqual(scroll.zoomScale, 3, accuracy: 0.01)
        scroll.bounds.size = CGSize(width: 700, height: 300)
        scroll.layoutIfNeeded()
        XCTAssertEqual(scroll.zoomScale, 1, accuracy: 0.01)
        XCTAssertEqual(scroll.imageView.frame, CGRect(x: 0, y: 0, width: 700, height: 300))
        XCTAssertEqual(scroll.contentOffset, .zero)
    }
}

/// Marker, um das App-Bundle aus dem Test-Bundle zu erreichen.
final class ContentRepositoryMarker {}

extension Bundle {
    var appBundle: Bundle {
        if bundleURL.pathExtension == "xctest" {
            let appURL = bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            if let b = Bundle(url: appURL), b.url(forResource: "content", withExtension: "json", subdirectory: "Content") != nil { return b }
        }
        return Bundle.main
    }
}
