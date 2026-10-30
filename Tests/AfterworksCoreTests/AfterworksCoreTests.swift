import XCTest
@testable import AfterworksCore

final class AfterworksCoreTests: XCTestCase {
    private func p(_ row: Int, _ col: Int) -> Position { Position(row: row, col: col) }
    private func applyFixture(_ level: Int, to campaign: inout Campaign) throws {
        for action in SolutionFixture.primary[level] { try campaign.apply(action) }
    }

    func testAllTwelveSolutionsAndIndependentFreshStarts() throws {
        var campaign = Campaign.new
        XCTAssertEqual(Balance.levels.count, 12)
        for index in Balance.levels.indices {
            XCTAssertEqual(campaign.current.levelIndex, index)
            XCTAssertEqual(campaign.current.board, Balance.levels[index].initialBoard)
            XCTAssertEqual(campaign.current.budget, Balance.levels[index].budget)
            XCTAssertTrue(campaign.undoHistory.isEmpty)
            try applyFixture(index, to: &campaign)
            let evaluation = campaign.dispatch()
            XCTAssertTrue(evaluation.meetsOrder, "Level \(index + 1): \(evaluation.totals)")
            XCTAssertEqual(campaign.current.spentCoins, Balance.levels[index].minimumCoins)
            XCTAssertEqual(campaign.currentStars, 3)
            try campaign.validate()
            for producer in evaluation.producers where producer.worked {
                XCTAssertEqual(producer.route.first, producer.position)
                XCTAssertEqual(producer.route.last, campaign.current.board.depot)
                XCTAssertEqual(Set(producer.route).count, producer.route.count)
                XCTAssertTrue(producer.route.contains { campaign.current.board[$0].infrastructure == .road })
                for (a, b) in zip(producer.route, producer.route.dropFirst()) { XCTAssertEqual(a.distance(to: b), 1) }
            }
            if index < 11 { try campaign.advance() }
        }
        XCTAssertEqual(campaign.totalStars, 36)
        XCTAssertTrue(campaign.isComplete)
        XCTAssertEqual(campaign.highestUnlockedIndex, 11)
        XCTAssertThrowsError(try campaign.advance())
    }

    func testExactMinimumCertificatesForAllTwelveLevels() throws {
        for index in Balance.levels.indices {
            let certificate = try MinimumCostProof.verify(levelIndex: index)
            print("Level \(index + 1): minimum \(certificate.claimedMinimum), checked \(certificate.checkedNetworks) networks, cheaper \(String(describing: certificate.cheaperCompletion))")
            XCTAssertTrue(certificate.proven, "\(certificate)")
        }
    }

    func testDirectDepotAdjacencyNeedsAnActualRoadRoute() throws {
        var campaign = Campaign.new
        try campaign.apply(.place(.orchard, p(5, 3)))
        XCTAssertEqual(campaign.dispatch().totals.food, 0)
        XCTAssertFalse(campaign.current.canAdvance)
        try campaign.applyRoadStroke([p(6, 4), p(5, 4)])
        XCTAssertEqual(campaign.dispatch().totals.food, 3)
    }

    private func customBoard(_ terrains: [(Position, Terrain)], pieces: [(Position, Piece)]) -> Board {
        var board = Board(tiles: Array(repeating: Tile(terrain: .cliff), count: 49), depot: p(6, 3))
        board[board.depot].terrain = .grass
        for (position, terrain) in terrains { board[position].terrain = terrain }
        for (position, piece) in pieces {
            if piece.isInfrastructure { board[position].infrastructure = piece }
            else { board[position].building = piece }
        }
        return board
    }

    func testBridgeOnlyPathAndDeadEndRoadSpurDoNotConnect() {
        let board = customBoard([(p(5,3),.water),(p(4,3),.grass),(p(5,4),.grass)],
                                pieces: [(p(5,3),.bridge),(p(4,3),.orchard),(p(5,4),.road)])
        XCTAssertEqual(Rules.route(from: p(4,3), on: board), [])
        XCTAssertEqual(Rules.evaluate(GameState(board: board)).totals.food, 0)
    }

    func testLongerSimpleRoadPathWinsOverBridgeOnlyShortcut() {
        let board = customBoard([(p(5,3),.water),(p(4,3),.grass),(p(5,4),.grass),(p(6,4),.grass)],
                                pieces: [(p(5,3),.bridge),(p(4,3),.orchard),(p(5,4),.road),(p(6,4),.road)])
        XCTAssertEqual(Rules.route(from: p(4,3), on: board), [p(4,3),p(5,3),p(5,4),p(6,4),p(6,3)])
        XCTAssertEqual(Rules.evaluate(GameState(board: board)).totals.food, 3)
    }

    func testDiagonalContactAndBuildingsDoNotCarryRoads() {
        let board = customBoard([(p(5,3),.grass),(p(4,2),.grass),(p(4,3),.grass),(p(3,3),.grass)],
                                pieces: [(p(5,3),.road),(p(4,2),.orchard),(p(4,3),.orchard),(p(3,3),.orchard)])
        let result = Rules.evaluate(GameState(board: board))
        XCTAssertEqual(result.totals.food, 3)
        XCTAssertEqual(result.producers.first { $0.position == p(4,2) }?.connected, false)
        XCTAssertEqual(result.producers.first { $0.position == p(3,3) }?.connected, false)
    }

    func testCoinRefundAndUndoRestoreExactState() throws {
        var campaign = Campaign.new
        let start = campaign.current
        try campaign.apply(.place(.orchard, p(4,3)))
        let placed = campaign.current
        XCTAssertEqual(campaign.current.spentCoins, 4)
        try campaign.apply(.remove(p(4,3)))
        XCTAssertEqual(campaign.current.budget, start.budget)
        XCTAssertTrue(campaign.undo())
        XCTAssertEqual(campaign.current, placed)
        XCTAssertTrue(campaign.undo())
        XCTAssertEqual(campaign.current, start)
        XCTAssertFalse(campaign.undo())
    }

    func testClearingCostsCoinsRemovalDoesNotRefundClearingAndUndoDoes() throws {
        var campaign = Campaign(current: GameState(levelIndex: 9))
        let original = campaign.current
        try campaign.apply(.clearWoodland(p(4,3)))
        try campaign.apply(.place(.road, p(4,3)))
        try campaign.apply(.remove(p(4,3)))
        XCTAssertEqual(campaign.current.spentCoins, 2)
        XCTAssertEqual(campaign.current.board[p(4,3)].terrain, .grass)
        for _ in 0..<3 { XCTAssertTrue(campaign.undo()) }
        XCTAssertEqual(campaign.current, original)
    }

    func testInvalidPlacementAndFailedStrokeAreAtomic() throws {
        var campaign = Campaign.new
        let before = campaign
        XCTAssertThrowsError(try campaign.apply(.place(.quarry, p(4,3))))
        XCTAssertThrowsError(try campaign.apply(.place(.road, p(0,0))))
        XCTAssertThrowsError(try campaign.apply(.place(.road, p(6,3))))
        XCTAssertThrowsError(try campaign.applyRoadStroke([p(5,3),p(4,4)]))
        XCTAssertEqual(campaign, before)
        try campaign.applyRoadStroke([p(6,3),p(5,3),p(4,3)])
        XCTAssertEqual(campaign.undoHistory.count, 1)
        XCTAssertEqual(campaign.current.spentCoins, 2)
        XCTAssertTrue(campaign.undo())
        XCTAssertEqual(campaign, before)
    }

    func testAllStarBandsUseNetCoinsAndBestScoreNeverRegresses() throws {
        var campaign = Campaign.new
        try applyFixture(0, to: &campaign)
        for position in [p(4,4),p(5,4),p(6,4)] { try campaign.apply(.place(.road, position)) }
        XCTAssertTrue(campaign.dispatch().meetsOrder)
        XCTAssertEqual(campaign.currentStars, 1)
        XCTAssertEqual(campaign.record(for: 0)?.spentCoins, 8)
        try campaign.apply(.remove(p(6,4)))
        campaign.dispatch()
        XCTAssertEqual(campaign.currentStars, 2)
        for position in [p(4,4),p(5,4)] { try campaign.apply(.remove(position)) }
        campaign.dispatch()
        XCTAssertEqual(campaign.currentStars, 3)
        let best = campaign.record(for: 0)
        for position in [p(4,4),p(5,4),p(6,4)] { try campaign.apply(.place(.road, position)) }
        campaign.dispatch()
        XCTAssertEqual(campaign.currentStars, 1)
        XCTAssertEqual(campaign.record(for: 0), best)
        try campaign.validate()
    }

    func testRepeatedDispatchIsIdempotentAndUnlockIsImmediate() throws {
        var campaign = Campaign.new
        try applyFixture(0, to: &campaign)
        let result = campaign.dispatch()
        let after = campaign
        for _ in 0..<20 { XCTAssertEqual(campaign.dispatch(), result) }
        XCTAssertEqual(campaign, after)
        XCTAssertEqual(campaign.records.count, 1)
        XCTAssertEqual(campaign.highestUnlockedIndex, 1)
        try campaign.startLevel(1)
        XCTAssertEqual(campaign.current.levelIndex, 1)
    }

    func testEditingInvalidatesCurrentResultButPreservesHistoryAndUndoRestoresResult() throws {
        var campaign = Campaign.new
        try applyFixture(0, to: &campaign)
        campaign.dispatch()
        let complete = campaign.current
        try campaign.apply(.remove(p(5,3)))
        XCTAssertNil(campaign.current.evaluation)
        XCTAssertFalse(campaign.current.canAdvance)
        XCTAssertEqual(campaign.totalStars, 3)
        XCTAssertThrowsError(try campaign.advance())
        XCTAssertTrue(campaign.undo())
        XCTAssertEqual(campaign.current, complete)
        try campaign.validate()
        try campaign.advance()
        XCTAssertThrowsError(try campaign.advance())
        XCTAssertEqual(campaign.current.board, Balance.levels[1].initialBoard)
    }

    func testReplayAndRestartNeverResetOtherLevelsOrUnlockLockedLevels() throws {
        var campaign = Campaign.new
        XCTAssertThrowsError(try campaign.startLevel(1))
        try applyFixture(0, to: &campaign)
        campaign.dispatch()
        try campaign.advance()
        try applyFixture(1, to: &campaign)
        campaign.dispatch()
        let records = campaign.records
        try campaign.startLevel(0)
        XCTAssertEqual(campaign.current.board, Balance.levels[0].initialBoard)
        try campaign.apply(.place(.road,p(5,3)))
        campaign.restartLevel()
        XCTAssertEqual(campaign.current.board, Balance.levels[0].initialBoard)
        XCTAssertEqual(campaign.records, records)
        XCTAssertTrue(campaign.undoHistory.isEmpty)
        XCTAssertThrowsError(try campaign.startLevel(3))
        try campaign.validate()
    }

    func testWetlandsAndConnectedReservoirBonusAreNotStacked() throws {
        var campaign = Campaign(current: GameState(levelIndex: 8))
        try applyFixture(8, to: &campaign)
        XCTAssertEqual(campaign.dispatch().totals.food, 10)
        try campaign.apply(.remove(p(2,3)))
        XCTAssertEqual(campaign.dispatch().totals.food, 6)
        var wet = Campaign(current: GameState(levelIndex: 7))
        try applyFixture(7, to: &wet)
        XCTAssertEqual(wet.dispatch().totals.food, 13)
    }

    func testPersistenceRoundTripAndValidationRejectsCorruption() throws {
        var campaign = Campaign.new
        try applyFixture(0, to: &campaign)
        campaign.dispatch()
        try campaign.apply(.remove(p(5,3)))
        let data = try JSONEncoder().encode(campaign)
        let decoded = try JSONDecoder().decode(Campaign.self, from: data)
        XCTAssertEqual(decoded, campaign)
        try decoded.validate()
        var bad = campaign; bad.current.budget += 1
        XCTAssertThrowsError(try bad.validate())
        bad = campaign; bad.records[0].stars = 1
        XCTAssertThrowsError(try bad.validate())
        bad = campaign; bad.current.board.tiles.removeLast()
        XCTAssertThrowsError(try bad.validate())
        bad = campaign; bad.current.levelIndex = 99
        XCTAssertThrowsError(try bad.validate())
        bad = campaign; bad.current.board[p(0,0)].terrain = .grass
        XCTAssertThrowsError(try bad.validate())
        bad = campaign; bad.records.append(bad.records[0])
        XCTAssertThrowsError(try bad.validate())
        bad = campaign; bad.undoHistory[0].levelIndex = -1
        XCTAssertThrowsError(try bad.validate())
    }

    func testPieceLimitsAndCliffsAreEnforced() throws {
        var campaign = Campaign.new
        try campaign.apply(.place(.orchard, p(4,3)))
        XCTAssertThrowsError(try campaign.apply(.place(.orchard, p(4,4))))
        let board = Balance.levels[5].initialBoard
        let cliff = Board.positions.first { board[$0].terrain == .cliff }!
        for piece in Piece.allCases { XCTAssertNotNil(Rules.terrainError(piece, at: cliff, on: board)) }
    }

    func testBridgeCrossingIsRequiredAndCannotBeReplacedByRoad() throws {
        var campaign = Campaign(current: GameState(levelIndex: 5))
        try applyFixture(5, to: &campaign)
        XCTAssertTrue(campaign.dispatch().meetsOrder)
        try campaign.apply(.remove(p(4,3)))
        XCTAssertFalse(campaign.dispatch().meetsOrder)
        let before = campaign
        XCTAssertThrowsError(try campaign.apply(.place(.road, p(4,3))))
        XCTAssertEqual(campaign, before)
        try campaign.apply(.place(.bridge, p(4,3)))
        XCTAssertTrue(campaign.dispatch().meetsOrder)
    }

    func testReservoirMustConnectAndItsRadiusIsManhattanDistance() {
        var board = customBoard([(p(5,3),.grass),(p(4,3),.grass),(p(3,3),.grass),
                                 (p(3,2),.grass),(p(3,1),.water),(p(4,2),.grass),(p(4,1),.water)],
                                pieces: [(p(5,3),.road),(p(4,3),.road),(p(3,2),.reservoir),(p(4,2),.field)])
        XCTAssertEqual(Rules.evaluate(GameState(board: board)).totals.food, 3)
        board[p(3,3)].infrastructure = .road
        XCTAssertEqual(Rules.evaluate(GameState(board: board)).totals.food, 5)
        board[p(4,2)].terrain = .wetland
        XCTAssertEqual(Rules.evaluate(GameState(board: board)).totals.food, 5)
        board[p(5,4)].terrain = .grass
        board[p(6,4)].terrain = .water
        board[p(5,4)].building = .field
        XCTAssertEqual(Rules.evaluate(GameState(board: board)).totals.food, 8)
    }

    func testClearingLastWoodlandDisablesCampButRemainsAValidSave() throws {
        var campaign = try SolutionFixture.completed()
        try campaign.startLevel(9)
        try campaign.apply(.place(.lumberCamp, p(3,2)))
        try campaign.apply(.clearWoodland(p(3,1)))
        XCTAssertNotNil(Rules.terrainError(.lumberCamp, at: p(3,2), on: campaign.current.board))
        try campaign.validate()
        campaign.restartLevel()
        campaign.current.board[p(3,0)].building = .lumberCamp
        campaign.current.budget -= Balance.definition(for: .lumberCamp).cost
        XCTAssertThrowsError(try campaign.validate())
    }

    func testNotEnoughCoinsCannotMutatePlan() throws {
        var campaign = Campaign(current: GameState(budget: 0))
        let before = campaign
        XCTAssertThrowsError(try campaign.apply(.place(.road, p(5,3))))
        XCTAssertEqual(campaign, before)
    }

    func testFailedDispatchDoesNotUnlockOrAwardStars() throws {
        var campaign = Campaign.new
        try campaign.apply(.place(.orchard, p(4,3)))
        XCTAssertFalse(campaign.dispatch().meetsOrder)
        XCTAssertEqual(campaign.currentStars, 0)
        XCTAssertEqual(campaign.highestUnlockedIndex, 0)
        XCTAssertTrue(campaign.records.isEmpty)
        XCTAssertThrowsError(try campaign.advance())
        try campaign.validate()
    }

    func testMalformedSavedResultsAndSkippedUnlocksAreRejected() throws {
        var campaign = Campaign.new
        try applyFixture(0, to: &campaign)
        campaign.dispatch()
        var bad = campaign
        bad.current.evaluation?.totals.food += 1
        XCTAssertThrowsError(try bad.validate())
        bad = campaign
        bad.records = [LevelRecord(levelIndex: 1, stars: 3, spentCoins: 6)]
        XCTAssertThrowsError(try bad.validate())
        bad = campaign
        bad.current.board[p(5,3)].building = .orchard
        XCTAssertThrowsError(try bad.validate())
        bad = campaign
        bad.records.removeAll()
        XCTAssertThrowsError(try bad.validate())
    }

    func testRouteSearchMatchesExhaustiveSimplePathsOnEverySmallNetwork() {
        let cells = [p(5,2),p(5,3),p(5,4),p(6,2),p(6,4),p(4,3)]
        for configuration in 0..<729 {
            var board = customBoard([], pieces: [])
            var value = configuration
            for cell in cells {
                let kind = value % 3; value /= 3
                if kind > 0 {
                    board[cell].terrain = kind == 1 ? .grass : .water
                    board[cell].infrastructure = kind == 1 ? .road : .bridge
                }
            }
            let actual = Rules.routes(on: board)
            for start in cells where board[start].infrastructure != nil {
                var shortest: Int?
                func visit(_ position: Position, seen: Set<Position>, hasRoad: Bool) {
                    if let shortest, seen.count >= shortest { return }
                    for next in position.neighbors where !seen.contains(next) {
                        if next == board.depot {
                            if hasRoad { shortest = seen.count + 1 }
                        } else if let piece = board[next].infrastructure {
                            visit(next, seen: seen.union([next]), hasRoad: hasRoad || piece == .road)
                        }
                    }
                }
                visit(start, seen: [start], hasRoad: board[start].infrastructure == .road)
                XCTAssertEqual(actual[start]?.count, shortest, "Network \(configuration), tile \(start.label)")
            }
        }
    }

}
