import Foundation

public enum Rules {
    public static func placementError(_ piece: Piece, at position: Position, in state: GameState) -> String? {
        guard state.board.contains(position) else { return "Place pieces inside the island." }
        guard position != state.board.depot else { return "The depot is reserved. Connect producers through a road network." }
        guard state.level.availablePieces.contains(piece) else { return "\(piece.title) is not available in this level." }
        let tile = state.board[position]
        guard tile.building == nil && tile.infrastructure == nil else {
            return "This tile is occupied. Remove its piece first."
        }
        let definition = Balance.definition(for: piece)
        guard state.count(of: piece) < state.level.limit(for: piece) else {
            return "All \(state.level.limit(for: piece)) \(piece.title.lowercased()) pieces are in use."
        }
        if let terrainError = terrainError(piece, at: position, on: state.board) { return terrainError }
        guard state.budget >= definition.cost else {
            return "\(piece.title) costs \(definition.cost). You have \(state.budget) gold coins left."
        }
        return nil
    }

    public static func terrainError(_ piece: Piece, at position: Position, on board: Board) -> String? {
        guard board.contains(position) else { return "This tile is outside the island." }
        let terrain = board[position].terrain
        if terrain == .cliff { return "Cliffs cannot hold buildings, roads or bridges." }
        let besideLake = position.neighbors.contains { board[$0].terrain == .water }
        let besideWoodland = position.neighbors.contains { board[$0].terrain == .woodland }
        switch piece {
        case .quarry:
            return terrain == .stone ? nil : "A quarry needs stone ground. Look for pale rock tiles."
        case .orchard:
            return terrain == .grass ? nil : "An orchard needs an empty meadow. Woodland can be cleared for \(Balance.clearingCost) coins."
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
            if terrain == .woodland { return "Clear this woodland for \(Balance.clearingCost) coins before building a road." }
            return terrain == .grass || terrain == .stone ? nil : "Use a bridge to cross lake or wetland."
        case .bridge:
            return terrain == .water || terrain == .wetland ? nil : "Bridges cross lake or wetland. Use a road on dry ground."
        }
    }

    /// Each delivery follows a simple path: a dead-end road cannot make a bridge-only route valid.
    public static func routes(on board: Board) -> [Position: [Position]] {
        let infrastructure = Set(Board.positions.filter {
            guard let piece = board[$0].infrastructure else { return false }
            return piece.isInfrastructure && terrainError(piece, at: $0, on: board) == nil
        })
        func shortestPath(from start: Position, excluding blocked: Set<Position>) -> [Position]? {
            var queue = [[start]]
            var seen = blocked.union([start])
            var head = 0
            while head < queue.count {
                let path = queue[head]; head += 1
                for neighbor in path.last!.neighbors.sorted() where !seen.contains(neighbor) {
                    if neighbor == board.depot { return path + [neighbor] }
                    guard infrastructure.contains(neighbor) else { continue }
                    seen.insert(neighbor)
                    queue.append(path + [neighbor])
                }
            }
            return nil
        }
        var result: [Position: [Position]] = [:]
        for position in infrastructure.sorted() {
            if board[position].infrastructure == .road {
                result[position] = shortestPath(from: position, excluding: [])
                continue
            }
            var best: [Position]?
            // Enumerate only the bridge prefix. Once the first road is reached,
            // ordinary BFS finds the shortest remaining path without revisiting it.
            func explore(_ prefix: [Position], visited: Set<Position>) {
                if let best, prefix.count + 2 >= best.count { return }
                for neighbor in prefix.last!.neighbors.sorted() where infrastructure.contains(neighbor) && !visited.contains(neighbor) {
                    if board[neighbor].infrastructure == .road {
                        if let suffix = shortestPath(from: neighbor, excluding: visited) {
                            let candidate = prefix + suffix
                            if best == nil || candidate.count < best!.count { best = candidate }
                        }
                    } else {
                        explore(prefix + [neighbor], visited: visited.union([neighbor]))
                    }
                }
            }
            explore([position], visited: [position])
            result[position] = best
        }
        return result
    }

    public static func route(from position: Position, on board: Board) -> [Position] {
        producerRoute(from: position, routes: routes(on: board))
    }

    private static func producerRoute(from position: Position, routes: [Position: [Position]]) -> [Position] {
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
            !producerRoute(from: position, routes: roadRoutes).isEmpty
        }
        var totals = Resources()
        let producers = Board.positions.compactMap { position -> ProducerResult? in
            guard let piece = board[position].building else { return nil }
            let definition = Balance.definition(for: piece)
            let invalidReason = terrainError(piece, at: position, on: board)
            let route = producerRoute(from: position, routes: roadRoutes)
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
                reason = "Needs a route with at least one road before the depot. Direct adjacency and bridge-only routes do not count."
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
        return Evaluation(totals: totals, producers: producers, meetsOrder: totals.meets(state.level.order), revision: state.revision)
    }

}
