import XCTest
@testable import AfterworksCore

final class AfterworksCoreTests: XCTestCase {
    private func p(_ row: Int, _ col: Int) -> Position { Position(row: row, col: col) }
    private func applyFixture(_ era: Int, to journey: inout Journey, variant: Int = 0) throws {
        for action in SolutionFixture.actions(forEra: era, variant: variant) { try journey.apply(action) }
    }
    private func eraTwo(variant: Int = 0) throws -> Journey {
        var journey = Journey.new
        try applyFixture(0, to: &journey, variant: variant)
        journey.dispatch()
        try journey.advance()
        return journey
    }

    func testOrthogonalRoadsConnectAndRoutesEndAtDepot() throws {
        var journey = Journey.new
        try applyFixture(0, to: &journey)
        let result = journey.dispatch()
        XCTAssertTrue(result.meetsOrder)
        XCTAssertEqual(result.totals, Resources(stone: 4, food: 6))
        for producer in result.producers {
            XCTAssertEqual(producer.route.first, producer.position)
            XCTAssertEqual(producer.route.last, journey.current.board.depot)
            for (a, b) in zip(producer.route, producer.route.dropFirst()) { XCTAssertEqual(a.distance(to: b), 1) }
            for routeTile in producer.route.dropFirst().dropLast() {
                XCTAssertNotNil(journey.current.board[routeTile].infrastructure)
                XCTAssertNil(journey.current.board[routeTile].building)
            }
        }
    }

    func testDiagonalRoadContactDoesNotConnect() throws {
        var journey = Journey.new
        try journey.apply(.place(.road, p(5, 3)))
        try journey.apply(.place(.road, p(5, 2)))
        try journey.apply(.place(.quarry, p(4, 1)))
        let result = journey.dispatch()
        XCTAssertEqual(result.totals.stone, 0)
        XCTAssertEqual(result.producers.first?.route, [])
        XCTAssertFalse(result.producers.first!.connected)
    }

    func testProducerDirectlyBesideDepotConnects() throws {
        var journey = Journey.new
        try journey.apply(.place(.orchard, p(6, 2)))
        let result = journey.dispatch()
        XCTAssertEqual(result.totals.food, 3)
        XCTAssertEqual(result.producers.first?.route, [p(6, 2), p(6, 3)])
    }

    func testBuildingsDoNotActAsRoads() throws {
        var journey = Journey.new
        try journey.apply(.place(.orchard, p(5, 3)))
        try journey.apply(.place(.orchard, p(4, 3)))
        let result = journey.dispatch()
        XCTAssertEqual(result.totals.food, 3)
        XCTAssertFalse(result.producers.first(where: { $0.position == p(4, 3) })!.connected)
    }

    func testInvalidPlacementSpendsNothingAndDoesNotCreateUndo() throws {
        var journey = Journey.new
        let before = journey
        XCTAssertThrowsError(try journey.apply(.place(.quarry, p(5, 3))))
        XCTAssertEqual(journey, before)
        XCTAssertThrowsError(try journey.apply(.place(.road, p(0, 0))))
        XCTAssertEqual(journey, before)
        XCTAssertThrowsError(try journey.apply(.place(.road, p(6, 3))))
        XCTAssertEqual(journey, before)
    }

    func testWaterCrossingNeedsBridgeAndBridgePersists() throws {
        var board = Board.initial
        board[p(5, 3)].terrain = .water
        board[p(4, 3)].terrain = .stone
        var journey = Journey(current: GameState(board: board))
        XCTAssertThrowsError(try journey.apply(.place(.road, p(5, 3))))
        try journey.apply(.place(.bridge, p(5, 3)))
        try journey.apply(.place(.quarry, p(4, 3)))
        XCTAssertEqual(journey.dispatch().totals.stone, 4)
        let future = Rules.transformedBoard(journey.current)
        XCTAssertEqual(future[p(5, 3)].terrain, .water)
        XCTAssertEqual(future[p(5, 3)].infrastructure, .bridge)
        XCTAssertTrue(future[p(5, 3)].inheritedInfrastructure)
    }

    func testRepeatedDispatchNeverAccumulatesGoods() throws {
        var journey = Journey.new
        try applyFixture(0, to: &journey)
        let once = journey.dispatch()
        let budget = journey.current.budget
        for _ in 0..<20 { XCTAssertEqual(journey.dispatch(), once) }
        XCTAssertEqual(journey.current.budget, budget)
        XCTAssertEqual(journey.current.evaluation?.totals, Resources(stone: 4, food: 6))
    }

    func testEditingInvalidatesSuccessfulDispatchAndUndoRestoresIt() throws {
        var journey = Journey.new
        try applyFixture(0, to: &journey)
        journey.dispatch()
        let before = journey.current
        XCTAssertTrue(before.canAdvance)
        try journey.apply(.place(.road, p(1, 3)))
        XCTAssertNil(journey.current.evaluation)
        XCTAssertFalse(journey.current.canAdvance)
        XCTAssertThrowsError(try journey.advance())
        XCTAssertTrue(journey.undo())
        XCTAssertEqual(journey.current, before)
        XCTAssertTrue(journey.current.canAdvance)
    }

    func testTransformationsPreserveCoordinatesAndUnconnectedStructuresLeaveNoLegacy() throws {
        var journey = Journey.new
        try applyFixture(0, to: &journey)
        try journey.apply(.place(.orchard, p(1, 2)))
        let future = Rules.transformedBoard(journey.current)
        XCTAssertEqual(future[p(4, 1)].terrain, .water)
        XCTAssertEqual(future[p(2, 2)].terrain, .woodland)
        XCTAssertEqual(future[p(4, 4)].terrain, .woodland)
        XCTAssertEqual(future[p(1, 2)].terrain, .grass)
        XCTAssertNil(future[p(1, 2)].building)
        XCTAssertEqual(future[p(4, 5)].terrain, .stone)
        XCTAssertEqual(future.depot, journey.current.board.depot)
    }

    func testConnectedSurplusProducerCreatesLegacy() throws {
        var journey = Journey.new
        try applyFixture(0, to: &journey)
        try journey.apply(.place(.orchard, p(3, 4)))
        XCTAssertEqual(journey.dispatch().totals.food, 9)
        try journey.advance()
        XCTAssertEqual(journey.current.board[p(3, 4)].terrain, .woodland)
    }

    func testPreviewIsReadOnlyAndMatchesActualAdvancement() throws {
        var journey = Journey.new
        for era in 0..<3 {
            try applyFixture(era, to: &journey)
            let before = journey
            let preview = Rules.transformedBoard(journey.current)
            XCTAssertEqual(journey, before)
            XCTAssertTrue(journey.dispatch().meetsOrder)
            try journey.advance()
            XCTAssertEqual(journey.current.board, preview)
        }
        XCTAssertTrue(journey.finished)
    }

    func testRoadStrokeHasOneUndoAndRestoresWholeState() throws {
        var journey = Journey.new
        journey.current.tutorialProgress = 2
        let before = journey.current
        try journey.applyRoadStroke([p(5, 3), p(4, 3), p(3, 3)])
        XCTAssertEqual(journey.undoHistory.count, 1)
        XCTAssertEqual(journey.current.budget, before.budget - 3)
        XCTAssertEqual(journey.current.revision, before.revision + 1)
        XCTAssertTrue(journey.undo())
        XCTAssertEqual(journey.current, before)
    }

    func testBlockedAndDiagonalRoadGesturesSpendNothing() throws {
        var journey = Journey.new
        let before = journey
        XCTAssertThrowsError(try journey.applyRoadStroke([p(2, 0), p(1, 0)]))
        XCTAssertEqual(journey, before)
        XCTAssertThrowsError(try journey.applyRoadStroke([p(5, 3), p(4, 2)]))
        XCTAssertEqual(journey, before)
    }

    func testRemovingUncommittedPieceRefundsAndInheritedRouteCostsOne() throws {
        var journey = Journey.new
        let initialBudget = journey.current.budget
        try journey.apply(.place(.orchard, p(6, 2)))
        try journey.apply(.remove(p(6, 2)))
        XCTAssertEqual(journey.current.budget, initialBudget)
        journey = try eraTwo()
        let before = journey.current
        try journey.apply(.remove(p(4, 2)))
        XCTAssertEqual(journey.current.budget, before.budget - Balance.inheritedRemovalCost)
        XCTAssertNil(journey.current.board[p(4, 2)].infrastructure)
        journey.undo()
        XCTAssertEqual(journey.current, before)
    }

    func testClearingCostsConstructionAndNeverCreatesTimber() throws {
        var journey = try eraTwo()
        let before = journey.current
        try journey.apply(.clearWoodland(p(2, 2)))
        XCTAssertEqual(journey.current.board[p(2, 2)].terrain, .grass)
        XCTAssertEqual(journey.current.budget, before.budget - 2)
        XCTAssertEqual(journey.dispatch().totals.timber, 0)
        journey.undo()
        XCTAssertEqual(journey.current, before)
    }

    func testFieldPreservesWetlandAndBonusesDoNotStack() throws {
        var journey = try eraTwo()
        try applyFixture(1, to: &journey)
        let result = journey.dispatch()
        XCTAssertEqual(result.totals.food, 10)
        try journey.advance()
        XCTAssertEqual(journey.current.board[p(3, 1)].terrain, .wetland)
        try journey.apply(.place(.field, p(3, 1)))
        XCTAssertEqual(journey.dispatch().totals.food, 5)
        XCTAssertEqual(Rules.transformedBoard(journey.current)[p(3, 1)].terrain, .wetland)

        var state = journey.current
        state.board[p(3, 0)].terrain = .water
        state.board[p(2, 0)].building = .reservoir
        for position in [p(2, 1), p(1, 1), p(1, 2), p(1, 3)] { state.board[position].infrastructure = .road }
        state.board[p(2, 1)].terrain = .grass
        XCTAssertEqual(Rules.evaluate(state).totals.food, 5)
    }

    func testDisconnectedReservoirCannotIrrigateOrCreateWetland() throws {
        var journey = try eraTwo()
        try journey.apply(.place(.reservoir, p(3, 1)))
        try journey.apply(.place(.road, p(5, 2)))
        try journey.apply(.place(.field, p(5, 1)))
        XCTAssertEqual(journey.dispatch().totals.food, 3)
        XCTAssertEqual(Rules.transformedBoard(journey.current)[p(3, 1)].terrain, .grass)
    }

    func testSaveLoadPreservesJourneyIncludingEvaluationCheckpointsAndUndo() throws {
        var journey = try eraTwo()
        try applyFixture(1, to: &journey)
        journey.current.tutorialProgress = 4
        journey.dispatch()
        let data = try JSONEncoder().encode(journey)
        var loaded = try JSONDecoder().decode(Journey.self, from: data)
        XCTAssertEqual(loaded, journey)
        try loaded.validate()
        try loaded.advance()
        XCTAssertEqual(loaded.current.eraIndex, 2)
        XCTAssertEqual(loaded.current.board, Rules.transformedBoard(journey.current))
    }

    func testAdvancementOccursOnceEvenIfCalledAgainImmediately() throws {
        var journey = Journey.new
        try applyFixture(0, to: &journey)
        journey.dispatch()
        try journey.advance()
        let after = journey
        XCTAssertThrowsError(try journey.advance())
        XCTAssertEqual(journey, after)
        XCTAssertEqual(journey.current.eraIndex, 1)
        XCTAssertEqual(journey.checkpoints.count, 2)
    }

    func testRestartAndRewindReturnToStartingCheckpoints() throws {
        var journey = try eraTwo()
        let startSecond = journey.current
        try applyFixture(1, to: &journey)
        journey.restartEra()
        XCTAssertEqual(journey.current, startSecond)
        XCTAssertEqual(journey.undoHistory, [])
        try journey.rewind()
        XCTAssertEqual(journey.current, GameState())
        XCTAssertEqual(journey.checkpoints.count, 1)
        XCTAssertFalse(journey.canRewind)
    }

    func testBothCompleteReproducibleThreeEraJourneys() throws {
        for variant in 0...1 {
            let journey = try SolutionFixture.completed(variant: variant)
            XCTAssertTrue(journey.finished)
            XCTAssertEqual(journey.eraResults.count, 3)
            XCTAssertTrue(journey.eraResults.allSatisfy(\.meetsOrder))
            XCTAssertEqual(journey.eraResults[0].totals, Resources(stone: 4, food: 6))
            XCTAssertEqual(journey.eraResults[1].totals, Resources(food: 10, timber: 4))
            XCTAssertEqual(journey.eraResults[2].totals, Resources(stone: 4, food: 8, timber: 8))
            XCTAssertEqual(journey.current.budget, 4)
            try journey.validate()
            let saved = try JSONDecoder().decode(Journey.self, from: JSONEncoder().encode(journey))
            XCTAssertEqual(saved, journey)
        }
    }

    func testEarlyPlacementChangesLaterFieldAndLumberOpportunities() throws {
        let west = try eraTwo()
        let east = try eraTwo(variant: 1)
        XCTAssertNotEqual(west.current.board, east.current.board)
        XCTAssertNil(Rules.placementError(.field, at: p(5, 1), in: west.current))
        XCTAssertNotNil(Rules.placementError(.field, at: p(5, 1), in: east.current))
        XCTAssertNotNil(Rules.placementError(.field, at: p(5, 5), in: west.current))
        XCTAssertNil(Rules.placementError(.field, at: p(5, 5), in: east.current))
        XCTAssertNil(Rules.placementError(.lumberCamp, at: p(1, 2), in: west.current))
        XCTAssertNotNil(Rules.placementError(.lumberCamp, at: p(1, 2), in: east.current))
        XCTAssertEqual(west.current.board[p(4, 2)].infrastructure, .road)
        XCTAssertNil(east.current.board[p(4, 2)].infrastructure)
        XCTAssertEqual(east.current.board[p(4, 2)].terrain, .woodland)
    }

    func testMalformedDecodedBoardIsRejectedBeforeUse() throws {
        var journey = Journey.new
        journey.current.board.tiles.removeLast()
        XCTAssertThrowsError(try journey.validate())
        journey = Journey.new
        journey.current.eraIndex = 9
        XCTAssertThrowsError(try journey.validate())
    }
}
