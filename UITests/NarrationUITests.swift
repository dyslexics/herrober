import XCTest

final class NarrationUITests: XCTestCase {
    func testImportierteHoertexteSuchenUndAnhoeren() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-lang", "de", "-screen", "ueber", "-darstellung", "hell"]
        app.launch()
        let library = app.buttons["narration.library"]
        guard library.waitForExistence(timeout: 8) else {
            throw XCTSkip("Importfixture nur im isolierten Audio-Prüfbuild vorhanden")
        }
        library.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("Zimmerkellners")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Die Aufgabe des Zimmerkellners")).firstMatch.tap()
        let listen = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "listen.")).firstMatch
        XCTAssertTrue(listen.waitForExistence(timeout: 5)); listen.tap()
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Stoppen"), evaluatedWith: listen)
        waitForExpectations(timeout: 5)
        Thread.sleep(forTimeInterval: 0.3)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "narration-import-playback"; shot.lifetime = .keepAlways; add(shot)
        listen.tap()
    }
}
