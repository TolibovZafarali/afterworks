import Foundation

/// A reproducible, exhaustive certificate for an authored level's three-star price.
/// This verifier is used by the test suite; it does not create playable levels.
public struct MinimumCostCertificate: Equatable, Sendable {
    public let levelIndex: Int
    public let claimedMinimum: Int
    public let fixtureCost: Int
    public let checkedNetworks: Int
    public let cheaperCompletion: Int?
    public var proven: Bool { fixtureCost == claimedMinimum && cheaperCompletion == nil }
}

public struct MinimumCostSolution: Sendable {
    public let spentCoins: Int
    public let actions: [GameAction]
    public let checkedNetworks: Int
}

public enum MinimumCostProof {
    /// Exhausts every cheaper connected infrastructure network, every useful woodland
    /// clearing, every reservoir site, and every eligible assignment of producers.
    /// Disconnected infrastructure and nonworking buildings can be removed from any
    /// winning layout without reducing output. Thus they cannot improve its minimum.
    /// The network bound uses an optimistic producer cost, ignoring all placement and
    /// routing restrictions, so pruning cannot discard a cheaper winning layout.
    public static func verify(levelIndex: Int) throws -> MinimumCostCertificate {
        guard Balance.levels.indices.contains(levelIndex) else { throw GameError("Unknown level.") }
        let level = Balance.levels[levelIndex]
        guard level.order.stone > 0 || level.order.food > 0 || level.order.timber > 0 else {
            throw GameError("The certificate requires a positive delivery order.")
        }
        guard level.limit(for: .reservoir) <= 1 else { throw GameError("The certificate supports at most one reservoir.") }
        var fixture = Campaign(current: GameState(levelIndex: levelIndex))
        for action in SolutionFixture.actions(forLevel: levelIndex) { try fixture.apply(action) }
        guard fixture.dispatch().meetsOrder else { throw GameError("The authored solution does not complete its order.") }
        let search = try search(level: level, ceiling: level.minimumCoins - 1, stopAfterFirst: true, networkLimit: nil)
        return MinimumCostCertificate(levelIndex: levelIndex, claimedMinimum: level.minimumCoins,
                                      fixtureCost: fixture.current.spentCoins, checkedNetworks: search.checked,
                                      cheaperCompletion: search.solution?.spentCoins)
    }

    /// Offline catalog tooling only. The shipping game reads bundled maps and never calls this search.
    /// A bounded search throws instead of returning an unproven optimum if its work limit is reached.
    public static func solve(level: LevelDefinition, maximumCoins: Int, networkLimit: Int = 250_000) throws -> MinimumCostSolution? {
        guard level.limit(for: .reservoir) <= 1 else { throw GameError("The solver supports at most one reservoir.") }
        let result = try search(level: level, ceiling: maximumCoins, stopAfterFirst: false, networkLimit: networkLimit)
        guard let solution = result.solution else { return nil }
        return MinimumCostSolution(spentCoins: solution.spentCoins, actions: solution.actions, checkedNetworks: result.checked)
    }

    private static func search(level: LevelDefinition, ceiling initialCeiling: Int, stopAfterFirst: Bool,
                               networkLimit: Int?) throws -> (solution: MinimumCostSolution?, checked: Int) {
        let producerFloor = optimisticProducerCost(level)
        let depot = level.initialBoard.depot
        let depotMask = bit(depot)
        let woods = Board.positions.filter { level.initialBoard[$0].terrain == .woodland }
        let woodlandMask = woods.reduce(UInt64(0)) { $0 | bit($1) }
        var candidates: [Position: (piece: Piece, cost: Int)] = [:]
        for position in Board.positions where position != depot {
            switch level.initialBoard[position].terrain {
            case .grass, .stone:
                if level.availablePieces.contains(.road) { candidates[position] = (.road, Balance.definition(for: .road).cost) }
            case .woodland:
                if level.availablePieces.contains(.road) { candidates[position] = (.road, Balance.definition(for: .road).cost + Balance.clearingCost) }
            case .water, .wetland:
                if level.availablePieces.contains(.bridge) { candidates[position] = (.bridge, Balance.definition(for: .bridge).cost) }
            case .cliff: break
            }
        }
        var seen: Set<UInt64> = [depotMask]
        var checked = 0
        var best: MinimumCostSolution?
        var ceiling = initialCeiling
        let orderedCandidates = candidates.keys.sorted()
        func visit(_ network: UInt64, cost: Int, roads: Int, bridges: Int) throws {
            if stopAfterFirst && best != nil { return }
            guard cost + producerFloor <= ceiling else { return }
            checked += 1
            if let networkLimit, checked > networkLimit { throw GameError("Exact search exceeded its network limit.") }
            if roads > 0 {
                var board = level.initialBoard
                var networkActions: [GameAction] = []
                for position in orderedCandidates where network & bit(position) != 0 {
                    if board[position].terrain == .woodland {
                        board[position].terrain = .grass
                        networkActions.append(.clearWoodland(position))
                    }
                    let piece = candidates[position]!.piece
                    board[position].infrastructure = piece
                    networkActions.append(.place(piece, position))
                }
                let networkWoods = network & woodlandMask
                // Enumerating clearing before production preserves woodland dependencies.
                for clearing in 0..<(1 << woods.count) {
                    var clearMask: UInt64 = 0
                    for index in woods.indices where clearing & (1 << index) != 0 { clearMask |= bit(woods[index]) }
                    if clearMask & networkWoods != 0 { continue }
                    let totalBase = cost + clearMask.nonzeroBitCount * Balance.clearingCost
                    guard totalBase + producerFloor <= ceiling else { continue }
                    var cleared = board
                    var actions = networkActions
                    for position in woods where clearMask & bit(position) != 0 {
                        cleared[position].terrain = .grass
                        actions.append(.clearWoodland(position))
                    }
                    let paths = Rules.routes(on: cleared)
                    let sites = Board.positions.filter {
                        $0 != depot && cleared[$0].infrastructure == nil &&
                        $0.neighbors.contains(where: { paths[$0] != nil })
                    }
                    var reservoirSites: [Position?] = [nil]
                    if level.limit(for: .reservoir) > 0 {
                        reservoirSites += sites.filter { Rules.terrainError(.reservoir, at: $0, on: cleared) == nil }.map(Optional.some)
                    }
                    for reservoir in reservoirSites {
                        let base = totalBase + (reservoir == nil ? 0 : Balance.definition(for: .reservoir).cost)
                        guard base < ceiling else { continue }
                        if let production = cheapestProduction(on: cleared, sites: sites, reservoir: reservoir,
                                                               level: level, maximumCost: ceiling - base) {
                            let reservoirAction = reservoir.map { [GameAction.place(.reservoir, $0)] } ?? []
                            let found = MinimumCostSolution(spentCoins: base + production.cost,
                                                            actions: actions + reservoirAction + production.actions,
                                                            checkedNetworks: checked)
                            best = found
                            if stopAfterFirst { return }
                            ceiling = found.spentCoins - 1
                        }
                    }
                }
            }
            guard cost < ceiling - producerFloor else { return }
            var frontier: Set<Position> = []
            for position in Board.positions where network & bit(position) != 0 {
                for neighbor in position.neighbors where network & bit(neighbor) == 0 && candidates[neighbor] != nil {
                    frontier.insert(neighbor)
                }
            }
            for position in frontier.sorted() {
                let info = candidates[position]!
                let nextCost = cost + info.cost
                let nextRoads = roads + (info.piece == .road ? 1 : 0)
                let nextBridges = bridges + (info.piece == .bridge ? 1 : 0)
                guard nextCost <= ceiling - producerFloor, nextRoads <= level.limit(for: .road),
                      nextBridges <= level.limit(for: .bridge) else { continue }
                let next = network | bit(position)
                guard seen.insert(next).inserted else { continue }
                try visit(next, cost: nextCost, roads: nextRoads, bridges: nextBridges)
            }
        }
        if ceiling >= producerFloor { try visit(depotMask, cost: 0, roads: 0, bridges: 0) }
        return (best, checked)
    }

    private static func requiredCount(_ amount: Int, output: Int) -> Int { (amount + output - 1) / output }

    private static func bit(_ position: Position) -> UInt64 { UInt64(1) << position.id }

    private static func optimisticProducerCost(_ level: LevelDefinition) -> Int {
        let quarryCount = requiredCount(level.order.stone, output: Balance.definition(for: .quarry).output)
        let campCount = requiredCount(level.order.timber, output: Balance.definition(for: .lumberCamp).output)
        let fixedCost = quarryCount * Balance.definition(for: .quarry).cost + campCount * Balance.definition(for: .lumberCamp).cost
        let wetlandCount = level.initialBoard.tiles.filter { $0.terrain == .wetland }.count
        var minimum = Int.max / 2
        for orchards in 0...level.limit(for: .orchard) {
            for fields in 0...level.limit(for: .field) {
                for reservoirs in 0...level.limit(for: .reservoir) {
                    let food = orchards * Balance.definition(for: .orchard).output + fields * Balance.definition(for: .field).output + Balance.fieldBonus * (reservoirs > 0 ? fields : min(fields, wetlandCount))
                    guard food >= level.order.food else { continue }
                    minimum = min(minimum, fixedCost + orchards * Balance.definition(for: .orchard).cost + fields * Balance.definition(for: .field).cost + reservoirs * Balance.definition(for: .reservoir).cost)
                }
            }
        }
        return minimum
    }

    private struct Production: Hashable {
        var quarries = 0
        var orchards = 0
        var camps = 0
        var fields = 0
        var food = 0
        var ordering: Int { (quarries << 32) | (orchards << 24) | (camps << 16) | (fields << 8) | food }
        var cost: Int {
            quarries * Balance.definition(for: .quarry).cost + orchards * Balance.definition(for: .orchard).cost +
            camps * Balance.definition(for: .lumberCamp).cost + fields * Balance.definition(for: .field).cost
        }
    }

    private static func cheapestProduction(on board: Board, sites: [Position], reservoir: Position?,
                                           level: LevelDefinition, maximumCost: Int) -> (cost: Int, actions: [GameAction])? {
        var states: [Production: [GameAction]] = [Production(): []]
        let quarriesNeeded = requiredCount(level.order.stone, output: Balance.definition(for: .quarry).output)
        let campsNeeded = requiredCount(level.order.timber, output: Balance.definition(for: .lumberCamp).output)
        let choicesBySite = sites.filter { $0 != reservoir }.map { site in
            (site, level.availablePieces.filter {
                !$0.isInfrastructure && $0 != .reservoir && Rules.terrainError($0, at: site, on: board) == nil
            })
        }
        // Independent capacity bounds deliberately ignore competition for cells.
        // They discard impossible reservoir/clearing choices before assignment DP.
        guard choicesBySite.filter({ $0.1.contains(.quarry) }).count >= quarriesNeeded,
              choicesBySite.filter({ $0.1.contains(.lumberCamp) }).count >= campsNeeded else { return nil }
        let orchardCapacity = min(level.limit(for: .orchard), choicesBySite.filter { $0.1.contains(.orchard) }.count) * Balance.definition(for: .orchard).output
        let fieldOutputs = choicesBySite.filter { $0.1.contains(.field) }.map { site, _ in
            Balance.definition(for: .field).output + ((board[site].terrain == .wetland || reservoir.map { $0.distance(to: site) <= Balance.reservoirRadius } == true) ? Balance.fieldBonus : 0)
        }.sorted(by: >)
        guard orchardCapacity + fieldOutputs.prefix(level.limit(for: .field)).reduce(0, +) >= level.order.food else { return nil }
        for (site, choices) in choicesBySite {
            var next = states
            for (state, previousActions) in states.sorted(by: { $0.key.ordering < $1.key.ordering }) {
                for piece in choices {
                    var candidate = state
                    switch piece {
                    case .quarry:
                        guard state.quarries < min(quarriesNeeded, level.limit(for: .quarry)) else { continue }
                        candidate.quarries += 1
                    case .lumberCamp:
                        guard state.camps < min(campsNeeded, level.limit(for: .lumberCamp)) else { continue }
                        candidate.camps += 1
                    case .orchard:
                        guard state.food < level.order.food, state.orchards < level.limit(for: .orchard) else { continue }
                        candidate.orchards += 1
                        candidate.food = min(level.order.food, candidate.food + Balance.definition(for: .orchard).output)
                    case .field:
                        guard state.food < level.order.food, state.fields < level.limit(for: .field) else { continue }
                        candidate.fields += 1
                        let boosted = board[site].terrain == .wetland || reservoir.map { $0.distance(to: site) <= Balance.reservoirRadius } == true
                        candidate.food = min(level.order.food, candidate.food + Balance.definition(for: .field).output + (boosted ? Balance.fieldBonus : 0))
                    default: continue
                    }
                    guard candidate.cost <= maximumCost else { continue }
                    if next[candidate] == nil { next[candidate] = previousActions + [.place(piece, site)] }
                }
            }
            states = next
        }
        guard let result = states.filter({ $0.key.quarries == quarriesNeeded && $0.key.camps == campsNeeded && $0.key.food >= level.order.food })
            .min(by: { lhs, rhs in
                if lhs.key.cost != rhs.key.cost { return lhs.key.cost < rhs.key.cost }
                return lhs.key.ordering < rhs.key.ordering
            }) else { return nil }
        return (result.key.cost, result.value)
    }
}
