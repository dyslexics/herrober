import XCTest
@testable import HerrOber

final class AufnahmenTests: XCTestCase {
    private func fixture() throws -> (URL, AufnahmenKatalog) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let repo = ContentRepository(bundle: Bundle(for: ContentRepositoryMarker.self).appBundle)
        let audio = try XCTUnwrap(repo.audioURL("tafel-37"))
        try FileManager.default.copyItem(at: audio, to: directory.appendingPathComponent("tafel-37.m4a"))
        let data = try XCTUnwrap(repo.vorleseDaten("tafel-37"))
        try JSONEncoder().encode(data).write(to: directory.appendingPathComponent("tafel-37.json"))
        let entry = AufnahmeEintrag(stem: "tafel-37", segment: 1, text: "Armleuchter.", language: "de-AT", category: "tafeln", supplement: true)
        let index = AufnahmenKatalog.Index(schema_version: 1, entries: [entry.id: entry])
        try JSONEncoder().encode(index).write(to: directory.appendingPathComponent("narration-index.json"))
        return (directory, AufnahmenKatalog(directory: directory))
    }

    func testExakterTextSpracheUndSegment() throws {
        let (directory, katalog) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (_, _, words) = try XCTUnwrap(katalog.aufnahme("Armleuchter.", sprache: "de-AT"))
        XCTAssertEqual(words.count, 1)
        XCTAssertEqual(words.first?.s, 1)
        XCTAssertNil(katalog.aufnahme("Armleuchter", sprache: "de-AT"))
        XCTAssertNil(katalog.aufnahme("Armleuchter.", sprache: "fr-FR"))
    }

    func testFehlendeUndFalscheMetadatenFallenZurueck() throws {
        let (directory, katalog) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("tafel-37.json")
        var data = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        var segments = try XCTUnwrap(data["segments"] as? [[String: Any]])
        segments[1]["text"] = "Anderer Inhalt"
        data["segments"] = segments
        try JSONSerialization.data(withJSONObject: data).write(to: path)
        XCTAssertNil(katalog.aufnahme("Armleuchter.", sprache: "de-AT"))
        try FileManager.default.removeItem(at: path)
        XCTAssertNil(katalog.aufnahme("Armleuchter.", sprache: "de-AT"))
        XCTAssertTrue(AufnahmenKatalog(directory: directory.appendingPathComponent("missing")).eintraege.isEmpty)
    }

    func testUnicodeSkalareZuUTF16() throws {
        let text = "A 𝄞 e\u{301}"
        XCTAssertEqual(AufnahmenKatalog.bereich(text, von: 2, bis: 3), NSRange(location: 2, length: 2))
        XCTAssertEqual(AufnahmenKatalog.bereich(text, von: 4, bis: 6), NSRange(location: 5, length: 2))
        XCTAssertNil(AufnahmenKatalog.bereich(text, von: -1, bis: 3))
        XCTAssertNil(AufnahmenKatalog.bereich(text, von: 1, bis: 99))
    }

    func testVorhandeneAufnahmeSpieltMitWortmarkierung() throws {
        let (directory, katalog) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let player = AufnahmePlayer(katalog: katalog)
        defer { player.stop() }
        let marked = expectation(description: "Echte Wortzeit aus vorhandener Aufnahme")
        var fulfilled = false
        XCTAssertTrue(player.lesen("Armleuchter.", sprache: "de-AT", markierung: { range in
            if range == NSRange(location: 0, length: 11), !fulfilled { fulfilled = true; marked.fulfill() }
        }, fertig: {}))
        wait(for: [marked], timeout: 5)
    }
}
