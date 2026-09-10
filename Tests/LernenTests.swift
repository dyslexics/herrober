import XCTest
@testable import HerrOber

final class LernenTests: XCTestCase {
    let repo = ContentRepository(bundle: Bundle(for: ContentRepositoryMarker.self).appBundle)
    func testLernEditionUndAlleQuellen() {
        let l = repo.lernen
        XCTAssertEqual(l.version, 1)
        XCTAssertEqual(l.begriffe.count, 40)
        XCTAssertEqual(l.fragen.count, 30)
        XCTAssertEqual(l.touren.count, 3)
        XCTAssertEqual(l.bildaufgaben.count, 3)
        XCTAssertEqual(l.leseuebungen.count, 12)
        XCTAssertEqual(l.kontexte.count, 6)
        for qs in [l.begriffe.map(\.quelle), l.fragen.map(\.quelle), l.leseuebungen.map(\.quelle), l.bildaufgaben.map(\.quelle), l.kontexte.map(\.quelle)] {
            for q in qs {
                switch q.art {
                case "kapitel":
                    let k = repo.kapitel(q.id)
                    XCTAssertNotNil(k)
                    XCTAssertTrue(k?.seiten.contains { $0.nr == q.seite } == true)
                    if let z = q.zitat {
                        let s = k?.seiten.first { $0.nr == q.seite }
                        let texte = s?.bloecke.flatMap { [$0.neu ?? ""] + ($0.items ?? []).map { $0.neu ?? "" } } ?? []
                        XCTAssertTrue(texte.contains(z), q.titel)
                    }
                case "tafel": XCTAssertNotNil(repo.tafel(q.id))
                case "menu": XCTAssertTrue(repo.alleKarten.contains { $0.bild == q.id })
                default: XCTFail(q.art)
                }
            }
        }
        for n in 1...10 { XCTAssertEqual(l.fragen.filter { $0.kapitel == String(format: "capitel-%02d", n) }.count, 3) }
        for f in l.fragen { XCTAssertTrue(f.antworten.indices.contains(f.richtig)); XCTAssertEqual(Set(f.antworten).count, 3) }
        XCTAssertEqual(Set(l.fragen.map(\.id)).count, 30)
        XCTAssertNotNil(UIImage(named: "Appsthrum"))
    }
    func testWortLupeSchreibweisenUndKontext() {
        let l = repo.lernen
        XCTAssertEqual(l.begriff(wort: "Hangerl,", kontext: "Das Hangerl")?.id, "hangerl")
        XCTAssertEqual(l.begriff(wort: "Fiſch-Meſſer", kontext: "Fiſch-Meſſer")?.id, "fischmesser")
        XCTAssertEqual(l.begriff(wort: "Credenz", kontext: "auf der Credenz")?.id, "kredenz")
        XCTAssertEqual(l.begriff(wort: "d’hôte", kontext: "Table d’hôte")?.id, "table-dhote")
        XCTAssertEqual(l.begriff(wort: "carte", kontext: "Servieren à la carte")?.id, "a-la-carte")
        XCTAssertNil(l.begriff(wort: "Table", kontext: "Service de table"))
        XCTAssertNil(l.begriff(wort: "carte", kontext: "carte"))
        XCTAssertNil(l.begriff(wort: "", kontext: ""))
    }
    func testLernstandErhaeltAltenLesestandUndWiederholung() throws {
        let suite = "lernen-tests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var alt = ProgressData()
        alt.zuletztKapitel = "capitel-03"; alt.zuletztSeite = "26"; alt.fibelBest = 12
        defaults.set(try JSONEncoder().encode(alt), forKey: "progress.v1")
        let p = ProgressStore(defaults: defaults)
        p.begriffMerken("hangerl"); p.frage("k02-1", richtig: false)
        p.schritt("gruss", tour: "erste-schicht", fertig: true); p.uebung("gedeck")
        let neu = ProgressStore(defaults: defaults)
        XCTAssertEqual(neu.data.zuletztSeite, "26"); XCTAssertEqual(neu.data.fibelBest, 12)
        XCTAssertTrue(neu.lern.wiederholen.contains("k02-1"))
        XCTAssertTrue(neu.lern.gemerkt.contains("hangerl"))
        XCTAssertTrue(neu.lern.tourSchritte.contains("erste-schicht/gruss"))
        XCTAssertTrue(neu.lern.uebungen.contains("gedeck"))
        neu.frage("k02-1", richtig: true)
        XCTAssertFalse(ProgressStore(defaults: defaults).lern.wiederholen.contains("k02-1"))
        neu.reset()
        let leer = ProgressStore(defaults: defaults)
        XCTAssertNil(leer.data.zuletztKapitel); XCTAssertTrue(leer.lern.gemerkt.isEmpty)
        XCTAssertTrue(leer.lern.beantwortet.isEmpty); XCTAssertTrue(leer.lern.tourSchritte.isEmpty)
    }
    func testFrakturBeispieleSindEchteAusschnitteUndMarkierbar() {
        for u in repo.lernen.leseuebungen {
            XCTAssertTrue(u.quelle.zitat?.contains(u.neu) == true, u.id)
            XCTAssertEqual(u.map.count, u.neu.count + 1)
            XCTAssertEqual(u.map.first, 0)
            XCTAssertEqual(u.map.last, u.alt.count)
            XCTAssertEqual(u.map, u.map.sorted())
            for r in u.antiqua { XCTAssertEqual(r.count, 2); XCTAssertLessThanOrEqual(r[1], u.alt.count) }
        }
    }
    func testGedeckKeineDoppeltenTeileUndNurRichtigeLoesung() {
        var g = GedeckAnordnung()
        g.lege("Gabel", nach: "rechts"); g.lege("Messer", nach: "links"); g.lege("Löffel", nach: "oben")
        XCTAssertTrue(g.vollstaendig); XCTAssertFalse(g.richtig)
        g.lege("Gabel", nach: "links")
        XCTAssertFalse(g.vollstaendig)
        XCTAssertNil(g.plaetze["rechts"])
        g.lege("Messer", nach: "rechts")
        XCTAssertTrue(g.richtig)
        g.lege("Teller", nach: "oben")
        XCTAssertTrue(g.richtig)
    }
}
