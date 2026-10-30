import XCTest

final class AfterworksUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-journey"]
        app.launch()
        let begin = app.buttons["new-journey"]
        XCTAssertTrue(begin.waitForExistence(timeout: 15))
        begin.tap()
        XCTAssertTrue(element("island-board").waitForExistence(timeout: 10))
    }

    func testCompleteThreeEraJourneyThroughRealTouches() {
        assertBudget(22)
        select("quarry")
        tapTile(6, 3)
        assertBudget(22)
        XCTAssertFalse(app.buttons["undo"].isEnabled)

        play(era: 0)
        assertBudget(4)
        capture("01-active-first-era")

        app.buttons["preview"].tap()
        assertBudget(4)
        XCTAssertFalse(app.buttons["undo"].isEnabled)
        XCTAssertFalse(app.buttons["dispatch"].isEnabled)
        app.buttons["inspect"].tap()
        XCTAssertEqual(app.buttons["preview"].label, "Back to planning")
        capture("02-future-preview")
        tapTile(4, 1)
        XCTAssertTrue(app.buttons["sheet-done"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["remove-inspected"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Future terrain: lake")).firstMatch.exists)
        app.buttons["sheet-done"].tap()
        app.buttons["preview"].tap()
        assertBudget(4)

        dispatchAndAdvance(to: "What remains")
        assertBudget(26)
        capture("03-transformed-second-era")
        play(era: 1)
        assertBudget(6)
        capture("04-active-second-era")
        dispatchAndAdvance(to: "A lasting place")
        assertBudget(26)
        capture("05-transformed-third-era")
        play(era: 2)
        assertBudget(4)
        capture("06-active-third-era")

        app.buttons["dispatch"].tap()
        waitUntilEnabled(app.buttons["advance"])
        app.buttons["advance"].tap()
        XCTAssertTrue(element("journey-complete").waitForExistence(timeout: 10))
        capture("07-journey-complete")
        let explore = app.buttons["explore-island"]
        revealVertically(explore)
        explore.tap()
        capture("08-final-landscape")
        XCTAssertFalse(app.buttons["preview"].isEnabled)
        XCTAssertFalse(app.buttons["remove"].isEnabled)
    }

    func testEditsUndoAndSuccessfulDispatchSurviveBackgroundAndRelaunch() {
        play(era: 0)
        app.buttons["dispatch"].tap()
        waitUntilEnabled(app.buttons["advance"])

        select("road")
        tapTile(1, 3)
        assertBudget(3)
        XCTAssertTrue(app.buttons["dispatch"].exists)
        XCTAssertFalse(app.buttons["advance"].exists)
        app.buttons["undo"].tap()
        assertBudget(4)
        waitUntilEnabled(app.buttons["advance"])

        XCUIDevice.shared.press(.home)
        app.activate()
        assertBudget(4)
        waitUntilEnabled(app.buttons["advance"])

        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["continue"].waitForExistence(timeout: 10))
        app.buttons["continue"].tap()
        assertBudget(4)
        waitUntilEnabled(app.buttons["advance"])
        capture("09-resumed-validated-plan")
    }

    func testPieceDragRoadStrokeUndoRestartAndRewind() {
        let quarry = app.buttons["piece-quarry"]
        XCTAssertTrue(quarry.isHittable)
        quarry.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: tileCoordinate(4, 1))
        assertBudget(17)

        select("road")
        tileCoordinate(5, 3).press(forDuration: 0.15, thenDragTo: tileCoordinate(2, 3))
        assertBudget(13)
        app.buttons["undo"].tap()
        assertBudget(17)

        restartEra()
        assertBudget(22)
        XCTAssertFalse(app.buttons["undo"].isEnabled)
        play(era: 0)
        dispatchAndAdvance(to: "What remains")
        select("road")
        tapTile(3, 2)
        assertBudget(25)
        restartEra()
        assertBudget(26)
        XCTAssertEqual(element("era-title").label, "What remains")

        app.buttons["inspect"].tap()
        tapTile(4, 1)
        XCTAssertTrue(app.buttons["sheet-done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Lake"].exists)
        app.buttons["sheet-done"].tap()

        app.buttons["menu"].tap()
        let rewind = app.buttons["Rewind one era"]
        revealVertically(rewind)
        rewind.tap()
        let confirm = app.alerts.buttons["Rewind"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(element("era-title").waitForExistence(timeout: 5))
        XCTAssertEqual(element("era-title").label, "First foundations")
        assertBudget(22)
        capture("10-rewound-first-era")
    }

    func testInterruptedDispatchAndAdvancementResumeExactlyOnce() {
        play(era: 0)
        app.buttons["dispatch"].tap()
        app.terminate()

        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["continue"].waitForExistence(timeout: 10))
        app.buttons["continue"].tap()
        assertBudget(4)
        XCTAssertEqual(element("era-title").label, "First foundations")
        waitUntilEnabled(app.buttons["advance"])

        app.buttons["advance"].tap()
        app.terminate()

        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["continue"].waitForExistence(timeout: 10))
        app.buttons["continue"].tap()
        XCTAssertEqual(element("era-title").label, "What remains")
        assertBudget(26)
        XCTAssertTrue(app.buttons["dispatch"].isEnabled)
        XCTAssertFalse(app.buttons["advance"].exists)
        XCTAssertFalse(app.buttons["undo"].isEnabled)
        capture("11-resumed-after-interrupted-advancement")
    }

    func testSettingsAndAccessibleTileActionsPersist() {
        app.buttons["menu"].tap()
        let sound = app.switches["sound-toggle"]
        let haptics = app.switches["haptics-toggle"]
        XCTAssertTrue(sound.waitForExistence(timeout: 5))
        let soundBefore = sound.value as? String
        let hapticsBefore = haptics.value as? String
        sound.tap()
        haptics.tap()
        let soundAfter = sound.value as? String
        let hapticsAfter = haptics.value as? String
        XCTAssertNotEqual(soundBefore, soundAfter)
        XCTAssertNotEqual(hapticsBefore, hapticsAfter)
        app.buttons["sheet-done"].tap()

        select("orchard")
        app.buttons["tile-list"].tap()
        let tile = app.buttons["tile-0-2"]
        revealVertically(tile)
        tile.tap()
        app.buttons["sheet-done"].tap()
        assertBudget(18)

        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["continue"].waitForExistence(timeout: 10))
        app.buttons["continue"].tap()
        assertBudget(18)
        app.buttons["menu"].tap()
        XCTAssertEqual(app.switches["sound-toggle"].value as? String, soundAfter)
        XCTAssertEqual(app.switches["haptics-toggle"].value as? String, hapticsAfter)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func assertBudget(_ expected: Int, file: StaticString = #filePath, line: UInt = #line) {
        let matching = app.descendants(matching: .any).matching(NSPredicate(
            format: "(identifier == %@ AND label == %@) OR label == %@",
            "budget-number", String(expected), "\(expected) construction remaining"
        )).firstMatch
        XCTAssertTrue(matching.waitForExistence(timeout: 5), "Expected \(expected) construction remaining", file: file, line: line)
    }

    private func select(_ piece: String) {
        let button = app.buttons["piece-\(piece)"]
        for _ in 0..<5 where !button.isHittable {
            let tray = app.scrollViews.firstMatch
            if button.exists && button.frame.midX < app.frame.midX { tray.swipeRight() }
            else { tray.swipeLeft() }
        }
        XCTAssertTrue(button.isHittable, "Piece \(piece) must be reachable in the tray")
        button.tap()
    }

    private func tapTile(_ row: Int, _ col: Int) {
        tileCoordinate(row, col).tap()
    }

    private func tileCoordinate(_ row: Int, _ col: Int) -> XCUICoordinate {
        let frame = element("island-board").frame
        let side = min(frame.width, frame.height) - 40
        let cell = side / 7
        let left = (frame.width - side) / 2 + 4
        let bottom = (frame.height - side) / 2 - 4
        let x = frame.minX + left + (CGFloat(col) + 0.5) * cell
        let y = frame.minY + frame.height - bottom - (CGFloat(6 - row) + 0.5) * cell
        return app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }

    private func waitUntilEnabled(_ control: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "exists == true AND enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: control)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed, file: file, line: line)
    }

    private func dispatchAndAdvance(to title: String) {
        app.buttons["dispatch"].tap()
        waitUntilEnabled(app.buttons["advance"])
        app.buttons["advance"].tap()
        let predicate = NSPredicate(format: "label == %@", title)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element("era-title"))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
        waitUntilEnabled(app.buttons["dispatch"])
    }

    private func restartEra() {
        app.buttons["menu"].tap()
        let restart = app.buttons["Restart era"]
        revealVertically(restart)
        restart.tap()
        let confirm = app.alerts.buttons["Restart this era"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(element("island-board").waitForExistence(timeout: 5))
    }

    private func revealVertically(_ control: XCUIElement) {
        for _ in 0..<5 where !control.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(control.isHittable)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // Ordinary touch actions matching SolutionFixture.primary in the rules package.
    private func play(era: Int) {
        let plans: [[(String, [(Int, Int)])]] = [
            [("road", [(5, 3), (4, 3), (4, 2), (3, 3), (2, 3)]),
             ("quarry", [(4, 1)]), ("orchard", [(2, 2), (4, 4)])],
            [("road", [(3, 2), (5, 2), (5, 0), (6, 0), (6, 1), (6, 2)]),
             ("reservoir", [(3, 1)]), ("field", [(5, 1), (4, 0)]), ("lumberCamp", [(3, 4)])],
            [("road", [(5, 4), (5, 5), (1, 3)]), ("quarry", [(4, 5)]),
             ("field", [(3, 1), (5, 1)]), ("lumberCamp", [(1, 2), (3, 4)])]
        ]
        for (piece, positions) in plans[era] {
            select(piece)
            for (row, col) in positions { tapTile(row, col) }
        }
    }
}
