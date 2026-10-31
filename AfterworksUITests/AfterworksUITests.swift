import XCTest
import AfterworksCore

final class AfterworksUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 180
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress"]
        app.launch()
        if !app.buttons["level-1"].waitForExistence(timeout: 15) {
            XCTFail("Level one was not exposed as a map button.\n\(app.debugDescription)")
        }
        assertLevel(2, isUnlocked: false)
        openLevel(0)
    }

    func testFirstTwelveLevelsThroughRealTouches() {
        executionTimeAllowance = 600
        let introduction = Array(Balance.levels.indices.prefix(12))
        for index in introduction {
            let level = Balance.levels[index]
            XCTAssertEqual(element("level-number").label, "Level \(index + 1) of \(Balance.levels.count)")
            assertCoins(level.budget)
            XCTAssertFalse(app.buttons["undo"].isEnabled)
            play(SolutionFixture.primary[index])
            assertCoins(level.budget - level.minimumCoins)
            if [0, 4, 7, 11].contains(index) { capture("\(String(format: "%02d", index + 1))-level-\(index + 1)-plan") }
            dispatchAndAssertStars(3)
            if [0, 11].contains(index) { capture("\(String(format: "%02d", index + 1))-level-\(index + 1)-three-stars") }
            if index != introduction.last {
                let next = app.buttons["next-level"]
                revealVertically(next)
                next.tap()
                waitForLevel(index + 1)
            }
        }
        resultToMap()
        assertTotalStars(36)
        for index in 0...12 {
            assertLevel(index + 1, isUnlocked: true)
        }
        assertLevel(14, isUnlocked: false)
        XCTAssertEqual(element("chapter-stars").label, "6 of 30 stars in this chapter")
        capture("13-first-twelve-complete-36-of-300-stars")
        assertLevel(Balance.levels.count, isUnlocked: false)
        XCTAssertEqual(element("chapter-stars").label, "0 of 30 stars in this chapter")
        capture("21-final-chapter-locked")
        let previous = app.buttons["previous-chapter"]
        revealVertically(previous, scrollID: "level-map-scroll")
        XCTAssertFalse(app.buttons["next-chapter"].isEnabled)
        previous.tap()
        assertChapter(8)
        app.buttons["next-chapter"].tap()
        assertChapter(9)
    }

    func testRepresentativeLaterLevelsThroughRealTouchesWithPreparedProgress() {
        executionTimeAllowance = 600
        for number in [13, 25, 50, 75, 100] {
            let index = number - 1
            app.terminate()
            app.launchArguments = ["--uitesting", "--reset-progress", "--ui-start-level", String(number)]
            app.launch()
            XCTAssertTrue(app.buttons["continue"].waitForExistence(timeout: 15))
            assertTotalStars(index * 3)
            assertChapter(index / 10)
            openLevel(index)
            assertCoins(Balance.levels[index].budget)
            XCTAssertFalse(app.buttons["undo"].isEnabled)
            play(SolutionFixture.primary[index])
            assertCoins(Balance.levels[index].budget - Balance.levels[index].minimumCoins)
            capture("\(number)-prepared-progress-level-\(number)-plan")
            dispatchAndAssertStars(3)
            capture("\(number)-prepared-progress-level-\(number)-three-stars")
            if number == Balance.levels.count { XCTAssertFalse(app.buttons["next-level"].exists) }
            resultToMap()
            assertTotalStars(number * 3)
            if number < Balance.levels.count {
                assertLevel(number + 1, isUnlocked: true)
                if number + 2 <= Balance.levels.count { assertLevel(number + 2, isUnlocked: false) }
            } else {
                XCTAssertEqual(element("chapter-stars").label, "30 of 30 stars in this chapter")
                capture("100-prepared-progress-complete-map")
            }
        }
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["continue"].waitForExistence(timeout: 15))
        assertTotalStars(Balance.levels.count * 3)
        assertChapter((Balance.levels.count - 1) / 10)
        app.buttons["continue"].tap()
        assertResultStars(3)
    }

    func testDirectDepotContactInvalidPlacementRefundAndUndo() throws {
        let state = GameState(levelIndex: 0)
        let initialCoins = state.budget
        let producer = try XCTUnwrap(state.board.depot.neighbors.first {
            Rules.placementError(.orchard, at: $0, in: state) == nil
        }, "The introduction must permit inspecting the direct-contact mistake")
        select(.orchard)
        tapTile(state.board.depot)
        assertCoins(initialCoins)
        XCTAssertFalse(app.buttons["undo"].isEnabled)

        tapTile(producer)
        assertCoins(initialCoins - Balance.definition(for: .orchard).cost)
        app.buttons["dispatch"].tap()
        waitUntilEnabled(app.buttons["dispatch"])
        XCTAssertFalse(element("level-complete").exists)
        XCTAssertFalse(app.buttons["next-level"].exists)
        assertCoins(initialCoins - Balance.definition(for: .orchard).cost)
        capture("14-adjacent-producer-needs-road")

        app.buttons["remove"].tap()
        tapTile(producer)
        assertCoins(initialCoins)
        app.buttons["undo"].tap()
        assertCoins(initialCoins - Balance.definition(for: .orchard).cost)
        app.buttons["undo"].tap()
        assertCoins(initialCoins)
        XCTAssertFalse(app.buttons["undo"].isEnabled)
        goToMap()
        assertTotalStars(0)
        assertLevel(2, isUnlocked: false)
    }

    func testStarTiersReplayAndBestResultPersistence() throws {
        executionTimeAllowance = 360
        let scoring = try scoringFixture()
        for index in 0..<scoring.index {
            play(SolutionFixture.primary[index])
            dispatchAndAssertStars(3)
            app.buttons["next-level"].tap()
            waitForLevel(index + 1)
        }
        let earlierStars = scoring.index * 3
        let level = Balance.levels[scoring.index]
        for (stars, extras) in [(1, scoring.oneStarExtras), (2, scoring.twoStarExtras), (3, [])] {
            play(SolutionFixture.primary[scoring.index] + extras)
            dispatchAndAssertStars(stars)
            let spent = level.budget - expectedRemaining(for: SolutionFixture.primary[scoring.index] + extras, level: scoring.index)
            XCTAssertEqual(element("result-spent").label, "\(spent) coins spent")
            if stars < 3 {
                retryResult(scoring.index)
                assertCoins(level.budget)
            }
        }
        capture("15-replayed-to-three-stars")
        resultToMap()
        assertTotalStars(earlierStars + 3)
        assertLevel(scoring.index + 2, isUnlocked: true)
        let replay = app.buttons["level-\(scoring.index + 1)"]
        revealVertically(replay, scrollID: "level-map-scroll")
        replay.tap()
        assertResultStars(3)
        retryResult(scoring.index)
        play(SolutionFixture.primary[scoring.index] + scoring.oneStarExtras)
        dispatchAndAssertStars(1)
        resultToMap()
        assertTotalStars(earlierStars + 3)

        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["continue"].waitForExistence(timeout: 10))
        assertTotalStars(earlierStars + 3)
        assertLevel(scoring.index + 2, isUnlocked: true)
    }

    func testPieceDragRoadStrokeRestartAndIndependentNextLevel() throws {
        let orchardAction = try XCTUnwrap(SolutionFixture.primary[0].first { action in
            if case .place(.orchard, _) = action { return true }; return false
        })
        guard case let .place(piece, position) = orchardAction else { return XCTFail("Missing orchard fixture") }
        let button = app.buttons["piece-\(piece.rawValue)"]
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: tileCoordinate(position))
        assertCoins(Balance.levels[0].budget - Balance.definition(for: piece).cost)
        app.buttons["undo"].tap()
        assertCoins(Balance.levels[0].budget)
        play(SolutionFixture.primary[0])
        dispatchAndAssertStars(3)
        app.buttons["next-level"].tap()
        waitForLevel(1)
        assertCoins(Balance.levels[1].budget)
        XCTAssertFalse(app.buttons["undo"].isEnabled)
        XCTAssertEqual(element("spent-coins").label, "0 coins spent")

        let roads = SolutionFixture.primary[1].compactMap { action -> Position? in
            if case let .place(.road, position) = action { return position }; return nil
        }
        let first = try XCTUnwrap(roads.first)
        let last = try XCTUnwrap(roads.last)
        XCTAssertTrue(first.row == last.row || first.col == last.col, "Level two teaches a straight road gesture")
        select(.road)
        tileCoordinate(first).press(forDuration: 0.15, thenDragTo: tileCoordinate(last))
        assertCoins(Balance.levels[1].budget - roads.count * Balance.definition(for: .road).cost)
        app.buttons["undo"].tap()
        assertCoins(Balance.levels[1].budget)
        XCTAssertFalse(app.buttons["undo"].isEnabled)

        select(.road)
        tapTile(first)
        restartLevel()
        assertCoins(Balance.levels[1].budget)
        XCTAssertFalse(app.buttons["undo"].isEnabled)
        goToMap()
        assertTotalStars(3)
        assertLevel(2, isUnlocked: true)
        assertLevel(3, isUnlocked: false)
        capture("16-restart-preserves-unlocked-levels")
    }

    func testSettingsAccessiblePlacementAndInterruptedCompletionPersist() throws {
        executionTimeAllowance = 240
        app.buttons["menu"].tap()
        let sound = app.switches["sound-toggle"]
        let haptics = app.switches["haptics-toggle"]
        XCTAssertTrue(sound.waitForExistence(timeout: 5))
        sound.tap()
        haptics.tap()
        let soundAfter = sound.value as? String
        let hapticsAfter = haptics.value as? String
        app.buttons["sheet-done"].tap()

        let orchardAction = try XCTUnwrap(SolutionFixture.primary[0].first { action in
            if case .place(.orchard, _) = action { return true }; return false
        })
        guard case let .place(_, orchardPosition) = orchardAction else { return XCTFail("Missing orchard fixture") }
        select(.orchard)
        app.buttons["tile-list"].tap()
        let tile = app.buttons["tile-\(orchardPosition.row)-\(orchardPosition.col)"]
        revealVertically(tile)
        tile.tap()
        app.buttons["sheet-done"].tap()
        assertCoins(Balance.levels[0].budget - Balance.definition(for: .orchard).cost)
        play(SolutionFixture.primary[0].filter { $0 != orchardAction })
        app.buttons["dispatch"].tap()
        app.terminate()

        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["continue"].waitForExistence(timeout: 10))
        assertTotalStars(3)
        assertLevel(2, isUnlocked: true)
        app.buttons["continue"].tap()
        if !element("level-complete").waitForExistence(timeout: 2) { app.buttons["dispatch"].tap() }
        assertResultStars(3)
        let next = app.buttons["next-level"]
        revealVertically(next)
        next.tap()
        app.terminate()

        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["continue"].waitForExistence(timeout: 10))
        assertTotalStars(3)
        assertLevel(3, isUnlocked: false)
        app.buttons["continue"].tap()
        waitForLevel(1)
        assertCoins(Balance.levels[1].budget)
        XCTAssertFalse(app.buttons["undo"].isEnabled)
        XCUIDevice.shared.press(.home)
        app.activate()
        assertCoins(Balance.levels[1].budget)
        app.buttons["menu"].tap()
        XCTAssertEqual(app.switches["sound-toggle"].value as? String, soundAfter)
        XCTAssertEqual(app.switches["haptics-toggle"].value as? String, hapticsAfter)
        capture("17-resumed-independent-level")
    }

    func testLargestDynamicTypeKeepsFirstLevelPlayable() {
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-progress",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["level-1"].waitForExistence(timeout: 10))
        capture("18-largest-type-level-map")
        openLevel(0)
        let board = element("island-board")
        let dispatch = app.buttons["dispatch"]
        XCTAssertTrue(board.isHittable)
        XCTAssertTrue(dispatch.isHittable)
        XCTAssertGreaterThanOrEqual(board.frame.width, 240)
        XCTAssertGreaterThanOrEqual(dispatch.frame.height, 44)
        XCTAssertGreaterThanOrEqual(board.frame.minY, app.frame.minY)
        XCTAssertLessThanOrEqual(board.frame.maxY, app.frame.maxY)
        XCTAssertLessThanOrEqual(dispatch.frame.maxY, app.frame.maxY)
        assertCoins(Balance.levels[0].budget)
        play(SolutionFixture.primary[0])
        assertCoins(Balance.levels[0].budget - Balance.levels[0].minimumCoins)
        capture("19-largest-type-first-plan")
        dispatchAndAssertStars(3)
        let next = app.buttons["next-level"]
        revealVertically(next)
        XCTAssertGreaterThanOrEqual(next.frame.height, 44)
        capture("20-largest-type-three-stars")
        next.tap()
        waitForLevel(1)
        assertCoins(Balance.levels[1].budget)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func assertCoins(_ expected: Int, file: StaticString = #filePath, line: UInt = #line) {
        let matching = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == %@ AND label == %@", "coins-number", "\(expected) gold coins remaining"
        )).firstMatch
        XCTAssertTrue(matching.waitForExistence(timeout: 5), "Expected \(expected) gold coins", file: file, line: line)
    }

    private func assertTotalStars(_ expected: Int, file: StaticString = #filePath, line: UInt = #line) {
        let total = element("total-stars")
        XCTAssertTrue(total.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(total.label, "\(expected) of \(Balance.levels.count * 3) stars", file: file, line: line)
    }

    private func assertResultStars(_ stars: Int, file: StaticString = #filePath, line: UInt = #line) {
        let result = element("result-stars")
        XCTAssertTrue(result.waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertEqual(result.label, "\(stars) of 3 stars", file: file, line: line)
    }

    private func dispatchAndAssertStars(_ stars: Int) {
        app.buttons["dispatch"].tap()
        assertResultStars(stars)
    }

    private func openLevel(_ index: Int) {
        chooseChapter(forLevel: index)
        let button = app.buttons["level-\(index + 1)"]
        revealVertically(button, scrollID: "level-map-scroll")
        button.tap()
        waitForLevel(index)
    }

    private func waitForLevel(_ index: Int) {
        let predicate = NSPredicate(format: "label == %@", "Level \(index + 1) of \(Balance.levels.count)")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element("level-number"))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
        waitUntilEnabled(app.buttons["dispatch"])
    }

    private func resultToMap() {
        let levels = app.buttons["levels"]
        revealVertically(levels)
        levels.tap()
        XCTAssertTrue(app.buttons["chapter-picker"].waitForExistence(timeout: 5))
    }

    private func assertChapter(_ index: Int) {
        let count = (Balance.levels.count + 9) / 10
        let predicate = NSPredicate(format: "label == %@", "Chapter \(index + 1) of \(count)")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element("chapter-title"))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    private func chooseChapter(forLevel index: Int) {
        let chapter = index / 10
        let expected = "Chapter \(chapter + 1) of \((Balance.levels.count + 9) / 10)"
        if element("chapter-title").exists && element("chapter-title").label == expected { return }
        let picker = app.buttons["chapter-picker"]
        revealVertically(picker, scrollID: "level-map-scroll")
        picker.tap()
        let choice = app.buttons["chapter-\(chapter + 1)"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        assertChapter(chapter)
    }

    private func assertLevel(_ number: Int, isUnlocked expected: Bool,
                             file: StaticString = #filePath, line: UInt = #line) {
        chooseChapter(forLevel: number - 1)
        let button = app.buttons["level-\(number)"]
        revealVertically(button, scrollID: "level-map-scroll", verifyHittable: false)
        XCTAssertTrue(button.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(button.isEnabled, expected, "Level \(number) unlock state", file: file, line: line)
    }

    private func goToMap() {
        app.buttons["menu"].tap()
        resultToMap()
    }

    private func restartLevel() {
        app.buttons["menu"].tap()
        let restart = app.buttons["restart-level"]
        revealVertically(restart)
        restart.tap()
        let confirm = app.alerts.buttons["Restart level"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(element("island-board").waitForExistence(timeout: 5))
    }

    private func retryResult(_ index: Int) {
        let retry = app.buttons["retry-level"]
        revealVertically(retry)
        retry.tap()
        let confirm = app.alerts.buttons["Restart level"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        waitForLevel(index)
    }

    private func select(_ piece: Piece) {
        let button = app.buttons["piece-\(piece.rawValue)"]
        revealInTray(button)
        button.tap()
    }

    private func revealInTray(_ control: XCUIElement) {
        let tray = app.scrollViews["building-tray-scroll"]
        XCTAssertTrue(tray.waitForExistence(timeout: 5))
        for _ in 0..<8 {
            let viewport = tray.frame.intersection(app.frame)
            if control.exists {
                let frame = control.frame
                let center = CGPoint(x: frame.midX, y: frame.midY)
                if frame.width > 0, frame.height > 0,
                   frame.minX >= viewport.minX, frame.maxX <= viewport.maxX,
                   viewport.contains(center) {
                    XCTAssertTrue(control.isHittable, "Visible tray control must be reachable")
                    return
                }
                if frame.midX < viewport.midX { tray.swipeRight(); continue }
            }
            tray.swipeLeft()
        }
        XCTFail("Tray control \(control.identifier) did not scroll into its visible viewport")
    }

    private func play(_ actions: [GameAction]) {
        var lastPiece: Piece?
        for action in actions {
            switch action {
            case let .place(piece, position):
                if piece != lastPiece { select(piece); lastPiece = piece }
                tapTile(position)
            case let .remove(position):
                app.buttons["remove"].tap()
                tapTile(position)
                lastPiece = nil
            case let .clearWoodland(position):
                let clear = app.buttons["clear-woods"]
                revealInTray(clear)
                clear.tap()
                tapTile(position)
                lastPiece = nil
            }
        }
    }

    private func tapTile(_ position: Position) { tileCoordinate(position).tap() }

    private func tileCoordinate(_ position: Position) -> XCUICoordinate {
        let frame = element("island-board").frame
        let side = min(frame.width, frame.height) - 40
        let cell = side / 7
        let left = (frame.width - side) / 2 + 4
        let bottom = (frame.height - side) / 2 - 4
        let x = frame.minX + left + (CGFloat(position.col) + 0.5) * cell
        let y = frame.minY + frame.height - bottom - (CGFloat(6 - position.row) + 0.5) * cell
        return app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }

    private func waitUntilEnabled(_ control: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "exists == true AND enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: control)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed, file: file, line: line)
    }

    private func revealVertically(_ control: XCUIElement, scrollID: String = "game-sheet-scroll",
                                  verifyHittable: Bool = true) {
        let scrollView = app.scrollViews[scrollID]
        if !scrollView.waitForExistence(timeout: 5) {
            XCTFail("The expected scrolling surface \(scrollID) did not appear.\n\(app.debugDescription)")
        }
        for _ in 0..<8 {
            let viewport = scrollView.frame.intersection(app.frame)
            if control.exists {
                let frame = control.frame
                let center = CGPoint(x: frame.midX, y: frame.midY)
                if frame.width > 0, frame.height > 0,
                   frame.minY >= viewport.minY, frame.maxY <= viewport.maxY,
                   viewport.contains(center) {
                    if verifyHittable { XCTAssertTrue(control.isHittable, "Visible control must be reachable") }
                    return
                }
                if frame.midY < viewport.midY { scrollView.swipeDown(); continue }
            }
            scrollView.swipeUp()
        }
        XCTFail("Control \(control.identifier) did not scroll into its visible viewport")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func expectedRemaining(for actions: [GameAction], level: Int) -> Int {
        var simulation = try! campaignAtLevel(level)
        for action in actions { try! simulation.apply(action) }
        return simulation.current.budget
    }

    private struct ScoringFixture {
        var index: Int
        var twoStarExtras: [GameAction]
        var oneStarExtras: [GameAction]
    }

    private func scoringFixture() throws -> ScoringFixture {
        for index in 0..<(Balance.levels.count - 1) {
            let level = Balance.levels[index]
            var simulation = try campaignAtLevel(index)
            for action in SolutionFixture.primary[index] { try simulation.apply(action) }
            var extras: [GameAction] = []
            var twoStar: [GameAction]?
            for position in Board.positions {
                guard Rules.placementError(.road, at: position, in: simulation.current) == nil else { continue }
                let action = GameAction.place(.road, position)
                try simulation.apply(action)
                extras.append(action)
                if level.stars(forSpent: simulation.current.spentCoins) == 2 && twoStar == nil { twoStar = extras }
                if level.stars(forSpent: simulation.current.spentCoins) == 1, let twoStar {
                    return ScoringFixture(index: index, twoStarExtras: twoStar, oneStarExtras: extras)
                }
            }
        }
        throw NSError(domain: "AfterworksUITests", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authored level offers all three scoring tiers through valid extra roads."])
    }

    private func campaignAtLevel(_ index: Int) throws -> Campaign {
        var campaign = Campaign.new
        for completed in 0..<index {
            for action in SolutionFixture.primary[completed] { try campaign.apply(action) }
            campaign.dispatch()
            try campaign.advance()
        }
        return campaign
    }
}
