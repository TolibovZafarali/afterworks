import Foundation

public struct Journey: Codable, Equatable, Sendable {
    public var current: GameState
    public var checkpoints: [GameState]
    public var undoHistory: [GameState]
    public var eraResults: [Evaluation]
    public var finished: Bool

    public init(current: GameState = GameState(), checkpoints: [GameState]? = nil,
                undoHistory: [GameState] = [], eraResults: [Evaluation] = [], finished: Bool = false) {
        self.current = current
        self.checkpoints = checkpoints ?? [current]
        self.undoHistory = undoHistory
        self.eraResults = eraResults
        self.finished = finished
    }
    public static var new: Journey { Journey() }
    public var canUndo: Bool { !finished && !undoHistory.isEmpty }
    public var canRewind: Bool { checkpoints.count > 1 }

    public mutating func apply(_ action: GameAction) throws {
        guard !finished else { throw GameError("This journey is complete. Restart the era or begin a new journey to build again.") }
        var next = current
        try Self.apply(action, to: &next)
        commitEdit(next)
    }

    /// A complete road gesture is transactional and occupies one undo entry.
    /// Crossing existing infrastructure costs nothing; a blocked gesture spends nothing.
    public mutating func applyRoadStroke(_ positions: [Position]) throws {
        guard !finished else { throw GameError("This journey is complete.") }
        var next = current
        var previous: Position?
        var changed = false
        for position in positions {
            guard next.board.contains(position) else { throw GameError("Keep the road inside the island.") }
            if let previous, previous.distance(to: position) > 1 {
                throw GameError("Roads join neighboring tiles. Diagonal steps do not connect.")
            }
            previous = position
            if position == next.board.depot || next.board[position].infrastructure != nil { continue }
            try Self.apply(.place(.road, position), to: &next)
            changed = true
        }
        if changed { commitEdit(next) }
    }

    private mutating func commitEdit(_ next: GameState) {
        undoHistory.append(current)
        if undoHistory.count > 64 { undoHistory.removeFirst(undoHistory.count - 64) }
        current = next
        current.revision += 1
        current.evaluation = nil
    }

    private static func apply(_ action: GameAction, to state: inout GameState) throws {
        switch action {
        case let .place(piece, position):
            if let problem = Rules.placementError(piece, at: position, in: state) { throw GameError(problem) }
            if piece.isInfrastructure { state.board[position].infrastructure = piece }
            else { state.board[position].building = piece }
            state.board[position].inheritedInfrastructure = false
            state.budget -= Balance.definition(for: piece).cost
        case let .remove(position):
            guard state.board.contains(position), position != state.board.depot else {
                throw GameError("The depot is reserved in every era.")
            }
            let tile = state.board[position]
            guard let piece = tile.building ?? tile.infrastructure else {
                throw GameError(tile.terrain == .woodland ? "Use Clear woodland to prepare this ground." : "There is no piece to remove here. Lakes and wetlands cannot be moved or filled.")
            }
            if tile.inheritedInfrastructure {
                guard state.budget >= Balance.inheritedRemovalCost else {
                    throw GameError("Removing an old route costs \(Balance.inheritedRemovalCost) construction.")
                }
                state.budget -= Balance.inheritedRemovalCost
            } else {
                state.budget += Balance.definition(for: piece).cost
            }
            state.board[position].building = nil
            state.board[position].infrastructure = nil
            state.board[position].inheritedInfrastructure = false
        case let .clearWoodland(position):
            guard state.board.contains(position), position != state.board.depot,
                  state.board[position].terrain == .woodland else { throw GameError("Only woodland can be cleared.") }
            guard state.board[position].building == nil && state.board[position].infrastructure == nil else {
                throw GameError("Remove this tile's piece before clearing the woodland.")
            }
            guard state.budget >= Balance.clearingCost else {
                throw GameError("Clearing woodland costs \(Balance.clearingCost) construction.")
            }
            state.board[position].terrain = .grass
            state.budget -= Balance.clearingCost
        }
    }

    @discardableResult public mutating func undo() -> Bool {
        guard !finished, let previous = undoHistory.popLast() else { return false }
        current = previous
        return true
    }

    @discardableResult public mutating func dispatch() -> Evaluation {
        if finished, let last = eraResults.last { return last }
        let result = Rules.evaluate(current)
        current.evaluation = result
        return result
    }

    public mutating func advance() throws {
        guard !finished, current.canAdvance, current.evaluation == Rules.evaluate(current) else {
            throw GameError("Dispatch this plan and complete the order before advancing.")
        }
        let result = current.evaluation!
        let transformed = Rules.transformedBoard(current)
        eraResults = Array(eraResults.prefix(current.eraIndex)) + [result]
        undoHistory.removeAll()
        if current.eraIndex == Balance.scenarios.count - 1 {
            current.board = transformed
            current.evaluation = nil
            current.revision += 1
            finished = true
        } else {
            current = GameState(eraIndex: current.eraIndex + 1, board: transformed,
                                tutorialProgress: current.tutorialProgress)
            checkpoints.append(current)
        }
    }

    public mutating func restartEra() {
        guard let checkpoint = checkpoints.last else { return }
        let tutorialProgress = current.tutorialProgress
        current = checkpoint
        current.tutorialProgress = tutorialProgress
        undoHistory.removeAll()
        eraResults = Array(eraResults.prefix(current.eraIndex))
        finished = false
    }

    public mutating func rewind() throws {
        guard canRewind else { throw GameError("You are already at the beginning of the journey.") }
        let tutorialProgress = current.tutorialProgress
        checkpoints.removeLast()
        current = checkpoints.last!
        current.tutorialProgress = tutorialProgress
        undoHistory.removeAll()
        eraResults = Array(eraResults.prefix(current.eraIndex))
        finished = false
    }

    /// Check decoded state before presenting it or indexing its fixed-size board.
    public func validate() throws {
        guard checkpoints.count >= 1, checkpoints.count <= Balance.scenarios.count,
              current.eraIndex == checkpoints.count - 1,
              undoHistory.count <= 64,
              eraResults.count == current.eraIndex + (finished ? 1 : 0) else {
            throw GameError("The saved journey has inconsistent checkpoints.")
        }
        for state in [current] + checkpoints + undoHistory {
            guard Balance.scenarios.indices.contains(state.eraIndex), state.board.tiles.count == Board.side * Board.side,
                  state.board.depot == Position(row: 6, col: 3), state.budget >= 0,
                  state.budget <= Balance.scenarios[state.eraIndex].budget, state.revision >= 0 else {
                throw GameError("The saved journey contains an invalid island or budget.")
            }
            for tile in state.board.tiles {
                guard tile.building?.isInfrastructure != true,
                      tile.infrastructure == nil || tile.infrastructure?.isInfrastructure == true,
                      tile.building == nil || tile.infrastructure == nil,
                      !tile.inheritedInfrastructure || tile.infrastructure != nil else {
                    throw GameError("The saved journey contains an invalid tile.")
                }
            }
            if let evaluation = state.evaluation {
                guard evaluation == Rules.evaluate(state) else { throw GameError("The saved delivery result is out of date.") }
            }
        }
    }
}
