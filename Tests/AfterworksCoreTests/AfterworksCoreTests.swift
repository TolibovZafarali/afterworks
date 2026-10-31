import XCTest
@testable import AfterworksCore

final class AfterworksCoreTests: XCTestCase {
    private func p(_ row: Int, _ col: Int) -> Position { Position(row: row, col: col) }
    private func applyFixture(_ level: Int, to campaign: inout Campaign) throws {
        for action in SolutionFixture.primary[level] { try campaign.apply(action) }
    }

    func testAllHundredSolutionsAndIndependentFreshStarts() throws {
        var campaign = Campaign.new
        XCTAssertEqual(Balance.levels.count, 100)
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
            if index < Balance.levels.count - 1 { try campaign.advance() }
        }
        XCTAssertEqual(campaign.totalStars, 300)
        XCTAssertTrue(campaign.isComplete)
        XCTAssertEqual(campaign.highestUnlockedIndex, 99)
        XCTAssertThrowsError(try campaign.advance())
    }

    func testExactMinimumCertificatesForAllHundredLevels() throws {
        var totalNetworks = 0
        var slowest = (level: 0, seconds: 0.0)
        let began = Date()
        for index in Balance.levels.indices {
            let start = Date()
            let certificate = try MinimumCostProof.verify(levelIndex: index)
            let elapsed = Date().timeIntervalSince(start)
            totalNetworks += certificate.checkedNetworks
            if elapsed > slowest.seconds { slowest = (index + 1, elapsed) }
            print("Level \(index + 1): minimum \(certificate.claimedMinimum), checked \(certificate.checkedNetworks) networks, cheaper \(String(describing: certificate.cheaperCompletion)), \(String(format: "%.3f", elapsed))s")
            XCTAssertTrue(certificate.proven, "\(certificate)")
            if index >= 12 { XCTAssertLessThanOrEqual(certificate.checkedNetworks, 20_000) }
        }
        print("Certificates: \(totalNetworks) total networks in \(String(format: "%.3f", Date().timeIntervalSince(began)))s; slowest level \(slowest.level) at \(String(format: "%.3f", slowest.seconds))s")
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


    func testOriginalTwelveDefinitionsAndOptimalActionsRemainIdentical() throws {
        let expected = ["9d3c827be4f2bd68", "81474e0d41f2c309", "8f3b6b1ad5e290ee", "94414b82b6339137",
                        "7017f8bdd4c50a6", "a54f7036c1f67f21", "2571947431dd7f34", "7dd13bb72cfc0d9a",
                        "ca915355c74f7a9f", "c3f01e04e25c1c4a", "dd50adc27712b01d", "5f734c225c1729cb"]
        for (index, level) in Balance.levels.prefix(12).enumerated() {
            var value = "\(level.index)|\(level.title)|\(level.subtitle)|\(level.hint)|\(level.order.stone),\(level.order.food),\(level.order.timber)|\(level.budget)|\(level.minimumCoins)|\(level.twoStarCoins)|"
            value += level.initialBoard.tiles.map { $0.terrain.rawValue }.joined(separator: ",")
            value += "|" + level.availablePieces.map(\.rawValue).joined(separator: ",")
            value += "|" + Piece.allCases.map { "\($0.rawValue):\(level.limit(for: $0))" }.joined(separator: ",")
            let encoded = try JSONEncoder().encode(SolutionFixture.primary[index])
            let object = try JSONSerialization.jsonObject(with: encoded)
            let canonical = try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
            value += "|" + String(data: canonical, encoding: .utf8)!
            let hash = value.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
            XCTAssertEqual(String(hash, radix: 16), expected[index], "Original level \(index + 1) changed")
            XCTAssertEqual(level.initialBoard.depot, p(6,3))
        }
    }

    func testCompletedTwelveLevelSaveUnlocksThirteenWithoutResettingProgress() throws {
        var legacy = Campaign.new
        for index in 0..<12 {
            try applyFixture(index, to: &legacy)
            legacy.dispatch()
            if index < 11 { try legacy.advance() }
        }
        let encoded = try JSONEncoder().encode(legacy)
        var restored = try JSONDecoder().decode(Campaign.self, from: encoded)
        try restored.validate()
        XCTAssertEqual(Balance.saveVersion, 2)
        XCTAssertEqual(restored.totalStars, 36)
        XCTAssertEqual(restored.highestUnlockedIndex, 12)
        XCTAssertFalse(restored.isComplete)
        XCTAssertEqual(restored.current, legacy.current)
        XCTAssertEqual(restored.undoHistory, legacy.undoHistory)
        try restored.advance()
        XCTAssertEqual(restored.current.levelIndex, 12)
        XCTAssertEqual(restored.current.board, Balance.levels[12].initialBoard)
        XCTAssertEqual(restored.records, legacy.records)
    }

    private func canonicalTopology(_ board: Board) -> String {
        let usable = Set(Board.positions.filter { ![Terrain.cliff, .water].contains(board[$0].terrain) })
        return (0..<8).map { transform in
            var cells = Array(repeating: Character("."), count: 49)
            for position in usable {
                var row = position.row, col = position.col
                if transform >= 4 { col = 6 - col }
                for _ in 0..<(transform % 4) { let oldRow = row; row = col; col = 6 - oldRow }
                cells[row * 7 + col] = "x"
            }
            return String(cells)
        }.min()!
    }

    func testAppendedTopologiesAreUniqueUnderEveryRotationAndReflection() {
        var signatures = Set(Balance.levels.prefix(12).map { canonicalTopology($0.initialBoard) })
        for level in Balance.levels.dropFirst(12) {
            XCTAssertTrue(signatures.insert(canonicalTopology(level.initialBoard)).inserted, "Repeated topology at level \(level.id)")
        }
        XCTAssertEqual(Set(Balance.levels.dropFirst(12).map { canonicalTopology($0.initialBoard) }).count, 88)
        XCTAssertEqual(Set(Balance.levels.map(\.title)).count, 100)
    }

    func testExpansionDifficultyBandsIncreaseRequiredBuildingsAndCost() {
        let bandCounts = [12, 16, 20, 20, 20]
        let buildingCounts = [6, 6, 7, 8, 9]
        let minimumCosts = [32, 35, 39, 44, 49]
        var previousAverage = 0.0
        for band in 0..<5 {
            let entries = ExpandedLevels.entries.enumerated().filter { $0.element.band == band }
            XCTAssertEqual(entries.count, bandCounts[band])
            let average = Double(entries.reduce(0) { $0 + $1.element.minimum }) / Double(entries.count)
            XCTAssertGreaterThan(average, previousAverage)
            previousAverage = average
            for (offset, entry) in entries {
                let actions = SolutionFixture.primary[offset + 12]
                let pieces = actions.compactMap { action -> Piece? in if case let .place(piece, _) = action { return piece }; return nil }
                XCTAssertEqual(pieces.filter { !$0.isInfrastructure }.count, buildingCounts[band])
                XCTAssertGreaterThanOrEqual(entry.minimum, minimumCosts[band])
                XCTAssertGreaterThanOrEqual(pieces.filter { $0.isInfrastructure }.count, 4 + band)
                XCTAssertGreaterThanOrEqual(pieces.filter { $0 == .bridge }.count, band == 4 ? 2 : 1)
                XCTAssertTrue(actions.contains { if case .clearWoodland = $0 { return true }; return false })
                XCTAssertEqual(pieces.contains(.reservoir), band != 1)
                XCTAssertGreaterThan(entry.order[0], 0)
                XCTAssertGreaterThan(entry.order[1], 0)
                XCTAssertGreaterThan(entry.order[2], 0)
                XCTAssertLessThanOrEqual(entry.networks, 20_000)
            }
        }
    }

    func testEveryLevelHasDistinctValidStarBands() {
        for level in Balance.levels {
            XCTAssertEqual(level.stars(forSpent: level.minimumCoins), 3)
            XCTAssertEqual(level.stars(forSpent: level.minimumCoins + 1), 2)
            XCTAssertEqual(level.stars(forSpent: level.twoStarCoins), 2)
            XCTAssertEqual(level.stars(forSpent: level.twoStarCoins + 1), 1)
            XCTAssertEqual(level.stars(forSpent: level.budget), 1)
            XCTAssertEqual(level.stars(forSpent: level.budget + 1), 0)
        }
    }

    func testOfflineSolverReturnsReproducibleOptimalWitnessAndRejectsIncompleteProof() throws {
        let level = Balance.levels[3]
        let first = try XCTUnwrap(MinimumCostProof.solve(level: level, maximumCoins: level.minimumCoins + 3))
        let second = try XCTUnwrap(MinimumCostProof.solve(level: level, maximumCoins: level.minimumCoins + 3))
        XCTAssertEqual(first.actions, second.actions)
        XCTAssertEqual(first.spentCoins, level.minimumCoins)
        var campaign = Campaign(current: GameState(levelIndex: level.index))
        for action in first.actions { try campaign.apply(action) }
        XCTAssertTrue(campaign.dispatch().meetsOrder)
        XCTAssertThrowsError(try MinimumCostProof.solve(level: level, maximumCoins: level.minimumCoins, networkLimit: 0))
    }

}
