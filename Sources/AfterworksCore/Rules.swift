import Foundation

public enum Rules {
    public static func placementError(_ piece: Piece, at position: Position, in state: GameState) -> String? {
        guard state.board.contains(position) else { return "Place pieces inside the island." }
        guard position != state.board.depot else { return "The depot is reserved in every era." }
        guard state.scenario.availablePieces.contains(piece) else { return "\(piece.title) is not available in this era." }
        let tile = state.board[position]
        guard tile.building == nil && tile.infrastructure == nil else {
            return "This tile is occupied. Remove its piece first."
        }
        let definition = Balance.definition(for: piece)
        guard state.count(of: piece) < definition.limit else {
            return "All \(definition.limit) \(piece.title.lowercased()) pieces are in use."
        }
        if let terrainError = terrainError(piece, at: position, on: state.board) { return terrainError }
        guard state.budget >= definition.cost else {
            return "\(piece.title) costs \(definition.cost). You have \(state.budget) construction left."
        }
        return nil
    }

    public static func terrainError(_ piece: Piece, at position: Position, on board: Board) -> String? {
        guard board.contains(position) else { return "This tile is outside the island." }
        let terrain = board[position].terrain
        let besideLake = position.neighbors.contains { board[$0].terrain == .water }
        let besideWoodland = position.neighbors.contains { board[$0].terrain == .woodland }
        switch piece {
        case .quarry:
            return terrain == .stone ? nil : "A quarry needs stone ground. Look for pale rock tiles."
        case .orchard:
            return terrain == .grass ? nil : "An orchard needs an empty meadow. Woodland can be cleared for \(Balance.clearingCost)."
        case .lumberCamp:
            guard terrain == .grass || terrain == .stone else { return "A lumber camp needs dry ground beside woodland." }
            return besideWoodland ? nil : "Place the camp directly beside woodland. Diagonal woodland does not count."
        case .field:
            guard terrain == .grass || terrain == .wetland else { return "A field needs meadow beside a lake, or wetland." }
            return terrain == .wetland || besideLake ? nil : "This field needs an orthogonally adjacent lake, or a wetland tile."
        case .reservoir:
            guard terrain == .grass || terrain == .stone else { return "A reservoir needs dry ground beside a lake." }
            return besideLake ? nil : "Place a reservoir directly beside a lake."
        case .road:
            if terrain == .woodland { return "Clear this woodland for \(Balance.clearingCost) before building a road." }
            return terrain == .grass || terrain == .stone ? nil : "Use a bridge to cross lake or wetland."
        case .bridge:
            return terrain == .water || terrain == .wetland ? nil : "Bridges cross lake or wetland. Use a road on dry ground."
        }
    }

    /// A breadth-first search through infrastructure only. Producer buildings never carry traffic.
    public static func routes(on board: Board) -> [Position: [Position]] {
        var routes: [Position: [Position]] = [board.depot: [board.depot]]
        var queue: [Position] = [board.depot]
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            for neighbor in current.neighbors.sorted() where routes[neighbor] == nil {
                guard let infrastructure = board[neighbor].infrastructure,
                      infrastructure.isInfrastructure,
                      terrainError(infrastructure, at: neighbor, on: board) == nil else { continue }
                routes[neighbor] = [neighbor] + routes[current]!
                queue.append(neighbor)
            }
        }
        return routes
    }

    public static func route(from position: Position, on board: Board) -> [Position] {
        producerRoute(from: position, depot: board.depot, routes: routes(on: board))
    }

    private static func producerRoute(from position: Position, depot: Position,
                                      routes: [Position: [Position]]) -> [Position] {
        if position == depot { return [depot] }
        let candidates = position.neighbors.compactMap { routes[$0] }.sorted {
            if $0.count != $1.count { return $0.count < $1.count }
            return $0[0] < $1[0]
        }
        guard let shortest = candidates.first else { return [] }
        return [position] + shortest
    }

    public static func evaluate(_ state: GameState) -> Evaluation {
        let board = state.board
        let roadRoutes = routes(on: board)
        let connectedReservoirs = Board.positions.filter { position in
            board[position].building == .reservoir &&
            terrainError(.reservoir, at: position, on: board) == nil &&
            !producerRoute(from: position, depot: board.depot, routes: roadRoutes).isEmpty
        }
        var totals = Resources()
        let producers = Board.positions.compactMap { position -> ProducerResult? in
            guard let piece = board[position].building else { return nil }
            let definition = Balance.definition(for: piece)
            let invalidReason = terrainError(piece, at: position, on: board)
            let route = producerRoute(from: position, depot: board.depot, routes: roadRoutes)
            let connected = !route.isEmpty
            let valid = invalidReason == nil
            var amount = valid && connected ? definition.output : 0
            var bonusReason: String?
            if piece == .field && valid && connected {
                if board[position].terrain == .wetland {
                    amount += Balance.fieldBonus
                    bonusReason = "wetland +\(Balance.fieldBonus)"
                } else if connectedReservoirs.contains(where: { $0.distance(to: position) <= Balance.reservoirRadius }) {
                    amount += Balance.fieldBonus
                    bonusReason = "reservoir +\(Balance.fieldBonus)"
                }
            }
            let reason: String
            if let invalidReason {
                reason = invalidReason
            } else if !connected {
                reason = "No route to the depot. Connect with orthogonal roads or bridges."
            } else if piece == .reservoir {
                reason = "Connected. Fields within \(Balance.reservoirRadius) orthogonal steps gain +\(Balance.fieldBonus) food."
            } else {
                let suffix = bonusReason.map { " (\($0))" } ?? ""
                reason = "Delivers \(amount) \(definition.resource?.rawValue ?? "goods")\(suffix)."
            }
            if let resource = definition.resource { totals[resource] += amount }
            return ProducerResult(position: position, piece: piece, connected: connected, valid: valid,
                                  resource: definition.resource, amount: amount, route: route, reason: reason)
        }
        return Evaluation(totals: totals, producers: producers, meetsOrder: totals.meets(state.scenario.order), revision: state.revision)
    }

    /// Used for both the read-only preview and the committed passage of time.
    public static func transformedBoard(_ state: GameState) -> Board {
        var board = state.board
        let successful = Set(evaluate(state).producers.filter(\.worked).map(\.position))
        for position in Board.positions {
            let tile = board[position]
            if let piece = tile.building, successful.contains(position) {
                switch piece {
                case .quarry: board[position].terrain = .water
                case .orchard: board[position].terrain = .woodland
                case .reservoir: board[position].terrain = .wetland
                case .lumberCamp: board[position].terrain = .grass
                case .field:
                    board[position].terrain = tile.terrain == .wetland ? .wetland : .grass
                case .road, .bridge: break
                }
            }
            board[position].building = nil
            board[position].inheritedInfrastructure = tile.infrastructure != nil
        }
        return board
    }

    public static func legacyDescription(at position: Position, in state: GameState) -> String {
        guard state.board.contains(position) else { return "Outside the island." }
        if position == state.board.depot { return "The depot stays here in all three eras." }
        let tile = state.board[position]
        if let building = tile.building {
            guard let result = evaluate(state).producers.first(where: { $0.position == position }), result.worked else {
                return "This \(building.title.lowercased()) will disappear without a legacy until it is valid and connected."
            }
            return Balance.definition(for: building).legacy
        }
        if let infrastructure = tile.infrastructure { return Balance.definition(for: infrastructure).legacy }
        return "This \(tile.terrain.title.lowercased()) remains in the next era."
    }
}
