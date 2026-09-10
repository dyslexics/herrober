import XCTest

final class LernenUITests: XCTestCase {
    private let app = XCUIApplication()
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }
    private func start(_ screen: String, reset: Bool = true, extras: [String] = []) {
        app.launchArguments = ["-lang", "de", "-screen", screen, "-darstellung", "hell"] + (reset ? ["-resetProgress"] : []) + extras
        app.launch()
    }
    private func sichtbar(_ element: XCUIElement, max: Int = 16) {
        for _ in 0..<max {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Nicht erreichbar: \(element)")
    }
    private func capture(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    func testGlossarSuchenMerkenUndBuchstelle() {
        start("glossar")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap(); search.typeText("Hangerl")
        let term = app.buttons["term.hangerl"]
        XCTAssertTrue(term.waitForExistence(timeout: 5)); term.tap()
        let save = app.buttons["term.save"]
        sichtbar(save); save.tap()
        XCTAssertTrue(save.label.contains("Gemerkt"))
        capture("learning-glossary")
        let source = app.buttons["learning.source"]
        sichtbar(source); source.tap()
        XCTAssertTrue(app.staticTexts["Handhabung des Serviertuches und der Utensilien"].waitForExistence(timeout: 5))
        app.terminate(); start("glossar", reset: false)
        app.buttons["Gemerkt"].tap()
        XCTAssertTrue(app.buttons["term.hangerl"].waitForExistence(timeout: 5))
    }
    func testFragenFeedbackWiederholungUndAbschluss() {
        start("lernfragen")
        let wrong = app.buttons["answer.1"] // Erste Frage: 0=Hangerl.
        XCTAssertTrue(wrong.waitForExistence(timeout: 10)); sichtbar(wrong); wrong.tap()
        let feedback = app.descendants(matching: .any).matching(identifier: "question.feedback").firstMatch
        sichtbar(feedback); capture("learning-question-feedback")
        XCTAssertTrue(feedback.label.contains("Text"))
        let next = app.buttons["question.next"]; sichtbar(next); next.tap()
        sichtbar(app.buttons["answer.2"]); app.buttons["answer.2"].tap() // zweite Frage, richtige Position
        sichtbar(next); next.tap()
        sichtbar(app.buttons["answer.1"]); app.buttons["answer.1"].tap() // dritte Frage
        sichtbar(next); next.tap()
        XCTAssertTrue(app.staticTexts["Runde abgeschlossen"].waitForExistence(timeout: 5))
        app.terminate(); start("lernen", reset: false)
        let repeatButton = app.buttons["learning.review"]; sichtbar(repeatButton); repeatButton.tap()
        XCTAssertTrue(app.staticTexts["1 / 1"].waitForExistence(timeout: 5))
        sichtbar(app.buttons["answer.0"]); app.buttons["answer.0"].tap()
        sichtbar(next); next.tap()
        app.terminate(); start("lernen", reset: false)
        XCTAssertFalse(app.buttons["learning.review"].exists)
    }
    func testTourStationUndFortschritt() {
        start("lernen")
        let tour = app.buttons["tour.erste-schicht"]
        XCTAssertTrue(tour.waitForExistence(timeout: 10)); tour.tap()
        let station = app.buttons["tour.continue"]
        XCTAssertTrue(station.waitForExistence(timeout: 5)); station.tap()
        XCTAssertTrue(app.staticTexts["Über das Verhalten des Kellners im Dienste"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        let done = app.switches["tour.done.gruss"]
        sichtbar(done); done.tap()
        app.terminate(); start("lernen", reset: false)
        app.buttons["tour.erste-schicht"].tap()
        XCTAssertTrue(app.buttons["tour.continue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tour.continue"].label.contains("unbekanntes"))
        capture("learning-tour")
    }
    func testGedeckMitTapsUndFibelVergleich() {
        start("bildaufgabe")
        XCTAssertTrue(app.buttons["place.item.Gabel"].waitForExistence(timeout: 10))
        app.buttons["place.item.Gabel"].tap(); app.buttons["place.slot.links"].tap()
        app.buttons["place.item.Messer"].tap(); app.buttons["place.slot.rechts"].tap()
        app.buttons["place.item.Löffel"].tap(); app.buttons["place.slot.oben"].tap()
        let check = app.buttons["place.check"]; sichtbar(check); check.tap()
        let feedback = app.descendants(matching: .any).matching(identifier: "image.feedback").firstMatch
        sichtbar(feedback); XCTAssertTrue(feedback.label.contains("Gut erkannt")); capture("learning-place-setting")
        app.terminate(); start("leseuebungen", reset: false)
        let reveal = app.buttons["reveal.satz-1"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 10)); sichtbar(reveal); reveal.tap()
        XCTAssertTrue(app.staticTexts["revealed.satz-1"].waitForExistence(timeout: 5))
        let listen = app.buttons["listen.satz-1"]; sichtbar(listen); listen.tap()
        capture("learning-fraktur-sentence")
        listen.tap()
    }
    func testAppsthrumAnBeidenStellenUndEnglisch() {
        start("settings")
        let link = app.links["appsthrum.link"]
        let fallback = app.buttons["appsthrum.link"]
        let brand = app.descendants(matching: .any).matching(identifier: "appsthrum.link").firstMatch
        sichtbar(brand)
        XCTAssertTrue(link.exists || fallback.exists || brand.exists)
        XCTAssertTrue(app.staticTexts["settings.idea"].exists)
        capture("learning-settings-appsthrum")
        app.terminate(); start("ueber", reset: false)
        sichtbar(brand, max: 30); capture("learning-about-appsthrum")
        app.terminate()
        app.launchArguments = ["-lang", "en", "-screen", "lernen", "-darstellung", "dunkel"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Discover & learn"].waitForExistence(timeout: 10))
        sichtbar(app.buttons["learning.glossary"]); capture("learning-english-dark")
    }
    func testWortLupeZeigtBedeutungUndOeffnetQuelle() {
        app.launchArguments = ["-lang", "de", "-kapitel", "capitel-02", "-neu", "-resetProgress"]
        app.launch()
        let absatz = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Das Serviertuch, das sogenannte")).firstMatch
        XCTAssertTrue(absatz.waitForExistence(timeout: 10)); sichtbar(absatz)
        absatz.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 80, dy: 12)).tap()
        let save = app.buttons["term.save"]
        sichtbar(save)
        XCTAssertTrue(save.exists)
        capture("learning-word-magnifier")
        let source = app.buttons["learning.source"]
        sichtbar(source); source.tap()
        XCTAssertTrue(app.staticTexts["Handhabung des Serviertuches und der Utensilien"].waitForExistence(timeout: 5))
        XCTAssertFalse(save.exists)
    }
    func testBildauswahlUndFranzoesischeMenuezeile() {
        start("lernen")
        sichtbar(app.buttons["learning.images"]); app.buttons["learning.images"].tap()
        app.buttons["image-task.fischmesser"].tap()
        sichtbar(app.buttons["image.answer.0"]); app.buttons["image.answer.0"].tap()
        let feedback = app.descendants(matching: .any).matching(identifier: "image.feedback").firstMatch
        sichtbar(feedback); XCTAssertTrue(feedback.label.contains("Vergleiche"))
        capture("learning-fish-knife")
        app.terminate(); start("lernen", reset: false)
        sichtbar(app.buttons["learning.menu"]); app.buttons["learning.menu"].tap()
        let french = app.buttons["listen.menuezeile-m2"]
        sichtbar(french); french.tap()
        capture("learning-strauss-menu")
        XCTAssertTrue(french.label.contains("Stoppen"))
        french.tap()
    }
}
