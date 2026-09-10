import XCTest

/// Kapitel „Warum dieses Buch“: Einstieg über die Über-Seite, Direktstart per -screen warum, beide Schriften.
final class WarumUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func text(_ teil: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", teil)).firstMatch
    }

    func testKapitelUeberDieUeberSeiteErreichbar() {
        app.launchArguments = ["-lang", "de", "-screen", "ueber", "-darstellung", "hell"]
        app.launch()
        let lesen = app.buttons["about.warum.read"]
        XCTAssertTrue(lesen.waitForExistence(timeout: 10))
        XCTAssertTrue(text("Warum ein Legasthenieverband").exists, "Titel des Kapitels auf der Karte")
        capture("warum-01-ueber-karte")
        lesen.tap()
        XCTAssertTrue(text("Lesen ist eine Kulturtechnik").waitForExistence(timeout: 8), "Erste Zwischenüberschrift im Kapitel")
        XCTAssertTrue(text("legasthenietrainer.com").exists, "Einladung am Ende ist Teil des Textes")
        capture("warum-02-kapitel-neu")
    }

    func testDirektstartInFrakturUndUmschalten() {
        app.launchArguments = ["-lang", "de", "-screen", "warum", "-alt", "-darstellung", "hell"]
        app.launch()
        let umschalter = app.segmentedControls.firstMatch
        XCTAssertTrue(umschalter.waitForExistence(timeout: 10))
        XCTAssertTrue(text("Warum ein Legasthenieverband").waitForExistence(timeout: 8))
        capture("warum-03-kapitel-alt")
        umschalter.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(text("Warum ein Legasthenieverband").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["warum.note"].exists, "Quellenhinweis unter dem Text")
        capture("warum-04-kapitel-neu-umgeschaltet")
    }

    func testEnglischeOberflaecheZeigtDeutschesKapitel() {
        app.launchArguments = ["-lang", "en", "-screen", "ueber", "-darstellung", "dunkel"]
        app.launch()
        let lesen = app.buttons["about.warum.read"]
        XCTAssertTrue(lesen.waitForExistence(timeout: 10))
        XCTAssertTrue(text("Read the chapter").exists)
        lesen.tap()
        XCTAssertTrue(text("Lesen ist eine Kulturtechnik").waitForExistence(timeout: 8))
        capture("warum-05-en-dunkel")
    }
}
