import XCTest

final class LernenLayoutUITests: XCTestCase {
    private let app = XCUIApplication()
    private func capture(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }
    private func sichtbar(_ element: XCUIElement) {
        for _ in 0..<16 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }
    func testGrosseSystemschriftUndQuerformat() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["-lang", "de", "-screen", "lernen", "-darstellung", "dunkel", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["tour.erste-schicht"].waitForExistence(timeout: 10))
        capture("learning-large-portrait")
        sichtbar(app.buttons["learning.glossary"]); app.buttons["learning.glossary"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Hangerl")
        app.buttons["term.hangerl"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        capture("learning-large-landscape-glossary")
        sichtbar(app.buttons["term.save"])
        XCTAssertTrue(app.buttons["term.save"].isHittable)
        app.terminate()
        app.launchArguments = ["-lang", "de", "-screen", "bildaufgabe", "-darstellung", "hell", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["place.slot.links"].waitForExistence(timeout: 10))
        sichtbar(app.buttons["place.slot.links"])
        XCTAssertTrue(app.buttons["place.slot.rechts"].isHittable)
        capture("learning-large-landscape-place")
        XCUIDevice.shared.orientation = .portrait
    }
    func testVorlesenMitWortmarkierung() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["-lang", "de", "-screen", "leseuebungen", "-darstellung", "hell"]
        app.launch()
        let listen = app.buttons["listen.satz-1"]
        XCTAssertTrue(listen.waitForExistence(timeout: 10)); sichtbar(listen); listen.tap()
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Stoppen"), evaluatedWith: listen)
        waitForExpectations(timeout: 5)
        Thread.sleep(forTimeInterval: 1.2) // Native Wortgrenzen abwarten, dann den tatsächlich markierten Text sichern.
        capture("learning-speaking-highlight")
        XCTAssertTrue(listen.label.contains("Stoppen"))
        listen.tap()
    }
}
