import XCTest

final class HerrOberUITests: XCTestCase {
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

    func testCoverOpensZoomsRotatesAndCloses() {
        app.launchArguments = ["-lang", "de", "-demoProgress", "-darstellung", "hell"]
        app.launch()
        let cover = app.buttons["cover.open"]
        XCTAssertTrue(cover.waitForExistence(timeout: 10))
        let smallCoverHeight = cover.frame.height
        capture("01-start-blue")
        cover.tap()
        let close = app.buttons["cover.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        let zoom = app.descendants(matching: .any).matching(identifier: "cover.zoom").firstMatch
        XCTAssertTrue(zoom.exists)
        XCTAssertGreaterThan(zoom.frame.height, smallCoverHeight * 2)
        capture("02-cover-fullscreen")
        zoom.doubleTap()
        capture("03-cover-zoom")
        zoom.doubleTap()
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        zoom.tap() // Wartet auf den abgeschlossenen Orientierungswechsel und prüft die Erreichbarkeit.
        XCTAssertTrue(close.isHittable)
        capture("04-cover-landscape")
        close.tap()
        XCTAssertTrue(cover.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
        cover.tap()
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        capture("05-cover-reopened")
        close.tap()
    }

    func testCreditAndDarkAppearance() {
        app.launchArguments = ["-lang", "de", "-screen", "settings", "-darstellung", "dunkel"]
        app.launch()
        let credit = app.staticTexts["settings.idea"]
        for _ in 0..<4 {
            if credit.exists && credit.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(credit.exists)
        XCTAssertEqual(credit.label, "Nach einer Idee von Rainer Ternik")
        capture("06-settings-credit-dark")
        app.terminate()
        app.launchArguments = ["-lang", "de", "-darstellung", "dunkel"]
        app.launch()
        let cover = app.buttons["cover.open"]
        XCTAssertTrue(cover.waitForExistence(timeout: 10))
        capture("07-start-dark")
        cover.tap()
        XCTAssertTrue(app.buttons["cover.close"].waitForExistence(timeout: 5))
        capture("08-cover-dark")
        app.buttons["cover.close"].tap()
    }
}
