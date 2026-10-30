import Foundation

public struct LevelRecord: Codable, Equatable, Identifiable, Sendable {
    public var levelIndex: Int
    public var stars: Int
    public var spentCoins: Int
    public var id: Int { levelIndex }
    public init(levelIndex: Int, stars: Int, spentCoins: Int) {
        self.levelIndex = levelIndex; self.stars = stars; self.spentCoins = spentCoins
    }
}

public struct Campaign: Codable, Equatable, Sendable {
    public var current: GameState
    public var undoHistory: [GameState]
    public var records: [LevelRecord]

    public init(current: GameState = GameState(), undoHistory: [GameState] = [], records: [LevelRecord] = []) {
        self.current = current; self.undoHistory = undoHistory; self.records = records
    }
    public static var new: Campaign { Campaign() }
    public var highestUnlockedIndex: Int {
        var index = 0
        while index < Balance.levels.count - 1 && record(for: index) != nil { index += 1 }
        return index
    }
    public var totalStars: Int { records.reduce(0) { $0 + $1.stars } }
    public var isComplete: Bool { records.count == Balance.levels.count }
    public var canUndo: Bool { !undoHistory.isEmpty }
    public var currentStars: Int { current.canAdvance ? current.level.stars(forSpent: current.spentCoins) : 0 }
    public func record(for index: Int) -> LevelRecord? { records.first { $0.levelIndex == index } }

    public mutating func apply(_ action: GameAction) throws {
        var next = current
        try Self.apply(action, to: &next)
        commitEdit(next)
    }

    /// A road gesture is atomic and occupies one undo entry, including clearing-free old cells.
    public mutating func applyRoadStroke(_ positions: [Position]) throws {
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
            if let error = Rules.placementError(piece, at: position, in: state) { throw GameError(error) }
            if piece.isInfrastructure { state.board[position].infrastructure = piece }
            else { state.board[position].building = piece }
            state.board[position].inheritedInfrastructure = false
            state.budget -= Balance.definition(for: piece).cost
        case let .remove(position):
            guard state.board.contains(position), position != state.board.depot else { throw GameError("The depot cannot be removed.") }
            let tile = state.board[position]
            guard let piece = tile.building ?? tile.infrastructure else {
                throw GameError(tile.terrain == .woodland ? "Use Clear woodland to prepare this ground." : "There is no piece to remove here.")
            }
            state.budget += Balance.definition(for: piece).cost
            state.board[position].building = nil
            state.board[position].infrastructure = nil
            state.board[position].inheritedInfrastructure = false
        case let .clearWoodland(position):
            guard state.board.contains(position), position != state.board.depot,
                  state.board[position].terrain == .woodland else { throw GameError("Only woodland can be cleared.") }
            guard state.board[position].building == nil && state.board[position].infrastructure == nil else {
                throw GameError("Remove this tile's piece before clearing the woodland.")
            }
            guard state.budget >= Balance.clearingCost else { throw GameError("Clearing woodland costs \(Balance.clearingCost) gold coins.") }
            state.board[position].terrain = .grass
            state.budget -= Balance.clearingCost
        }
    }

    @discardableResult public mutating func undo() -> Bool {
        guard let previous = undoHistory.popLast() else { return false }
        current = previous
        return true
    }

    /// Recording success is synchronous. Animation and repeated dispatch never award duplicate progress.
    @discardableResult public mutating func dispatch() -> Evaluation {
        let evaluation = Rules.evaluate(current)
        current.evaluation = evaluation
        if evaluation.meetsOrder {
            let candidate = LevelRecord(levelIndex: current.levelIndex, stars: currentStars, spentCoins: current.spentCoins)
            if let index = records.firstIndex(where: { $0.levelIndex == candidate.levelIndex }) {
                if candidate.spentCoins < records[index].spentCoins { records[index] = candidate }
            } else {
                records.append(candidate)
                records.sort { $0.levelIndex < $1.levelIndex }
            }
        }
        return evaluation
    }

    public mutating func startLevel(_ index: Int) throws {
        guard Balance.levels.indices.contains(index), index <= highestUnlockedIndex else {
            throw GameError("Complete the preceding level to unlock this island.")
        }
        current = GameState(levelIndex: index)
        undoHistory.removeAll()
    }

    public mutating func restartLevel() {
        current = GameState(levelIndex: current.levelIndex)
        undoHistory.removeAll()
    }

    public mutating func advance() throws {
        guard current.canAdvance, current.evaluation == Rules.evaluate(current), record(for: current.levelIndex) != nil else {
            throw GameError("Complete this order with Dispatch before opening the next level.")
        }
        guard current.levelIndex + 1 < Balance.levels.count else { throw GameError("All twelve levels are complete. Replay any island to improve its stars.") }
        try startLevel(current.levelIndex + 1)
    }

    public func validate() throws {
        guard records.count <= Balance.levels.count, Set(records.map(\.levelIndex)).count == records.count,
              undoHistory.count <= 64 else { throw GameError("Saved progress has inconsistent records.") }
        for record in records {
            guard Balance.levels.indices.contains(record.levelIndex), (1...3).contains(record.stars) else {
                throw GameError("Saved progress contains an invalid level record.")
            }
            let level = Balance.levels[record.levelIndex]
            guard record.spentCoins >= level.minimumCoins, record.spentCoins <= level.budget,
                  record.stars == level.stars(forSpent: record.spentCoins),
                  (0..<record.levelIndex).allSatisfy({ self.record(for: $0) != nil }) else {
                throw GameError("Saved progress contains an invalid score or unlock.")
            }
        }
        guard Balance.levels.indices.contains(current.levelIndex), current.levelIndex <= highestUnlockedIndex else {
            throw GameError("Saved progress refers to a locked island.")
        }
        for state in [current] + undoHistory {
            guard state.levelIndex == current.levelIndex, state.board.tiles.count == 49,
                  state.board.depot == state.level.initialBoard.depot, state.budget >= 0,
                  state.budget <= state.level.budget, state.revision >= 0 else {
                throw GameError("The saved level contains an invalid board or coin balance.")
            }
            var spent = 0
            for position in Board.positions {
                let tile = state.board[position]
                let original = state.level.initialBoard[position]
                guard tile.building?.isInfrastructure != true,
                      tile.infrastructure == nil || tile.infrastructure?.isInfrastructure == true,
                      tile.building == nil || tile.infrastructure == nil, !tile.inheritedInfrastructure else {
                    throw GameError("The saved level contains an invalid tile.")
                }
                if tile.terrain != original.terrain {
                    guard original.terrain == .woodland && tile.terrain == .grass else { throw GameError("The saved terrain is invalid.") }
                    spent += Balance.clearingCost
                }
                if let piece = tile.building ?? tile.infrastructure {
                    guard position != state.board.depot, state.level.availablePieces.contains(piece),
                          Rules.terrainError(piece, at: position, on: state.board) == nil || (piece == .lumberCamp && (tile.terrain == .grass || tile.terrain == .stone)) else {
                        throw GameError("The saved level contains an invalid placement.")
                    }
                    spent += Balance.definition(for: piece).cost
                }
            }
            guard spent == state.spentCoins, Piece.allCases.allSatisfy({ state.count(of: $0) <= state.level.limit(for: $0) }) else {
                throw GameError("The saved coin balance or piece count is invalid.")
            }
            if let evaluation = state.evaluation {
                guard evaluation == Rules.evaluate(state) else { throw GameError("The saved delivery result is out of date.") }
            }
        }
        if current.canAdvance {
            guard let record = record(for: current.levelIndex), record.spentCoins <= current.spentCoins else {
                throw GameError("The completed level is missing its score.")
            }
        }
    }
}
