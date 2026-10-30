import Foundation

public struct Position: Codable, Hashable, Comparable, Identifiable, Sendable {
    public var row: Int
    public var col: Int
    public init(row: Int, col: Int) { self.row = row; self.col = col }
    public var id: Int { row * Board.side + col }
    public var label: String { "\(String(UnicodeScalar(65 + max(0, min(col, 25)))!))\(row + 1)" }
    public var neighbors: [Position] {
        [Position(row: row - 1, col: col), Position(row: row, col: col - 1),
         Position(row: row, col: col + 1), Position(row: row + 1, col: col)]
            .filter { $0.row >= 0 && $0.row < Board.side && $0.col >= 0 && $0.col < Board.side }
    }
    public func distance(to other: Position) -> Int { abs(row - other.row) + abs(col - other.col) }
    public static func < (lhs: Position, rhs: Position) -> Bool { lhs.id < rhs.id }
}

public enum Terrain: String, Codable, CaseIterable, Sendable {
    case grass, stone, water, woodland, wetland, cliff
    public var title: String {
        switch self {
        case .grass: return "Meadow"
        case .stone: return "Stone ground"
        case .water: return "Lake"
        case .woodland: return "Woodland"
        case .wetland: return "Wetland"
        case .cliff: return "Cliff"
        }
    }
    public var description: String {
        switch self {
        case .grass: return "Dry, usable ground for orchards, fields and camps."
        case .stone: return "Quarries produce stone here. Roads can cross this dry ground."
        case .water: return "Irrigates adjacent fields. Cross with a bridge. Lakes cannot be moved or filled."
        case .woodland: return "Supplies adjacent lumber camps. Clear for \(Balance.clearingCost) gold coins; clearing produces no timber."
        case .wetland: return "Fields here produce +\(Balance.fieldBonus) food. Cross with a bridge; wetland cannot be filled."
        case .cliff: return "Solid cliff. Buildings, roads and bridges cannot be placed here."
        }
    }
}

public enum Piece: String, Codable, CaseIterable, Identifiable, Sendable {
    case quarry, orchard, lumberCamp, field, reservoir, road, bridge
    public var id: String { rawValue }
    public var isInfrastructure: Bool { self == .road || self == .bridge }
    public var title: String { Balance.definition(for: self).title }
}

public enum Resource: String, Codable, CaseIterable, Identifiable, Sendable {
    case stone, food, timber
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public struct Resources: Codable, Equatable, Sendable {
    public var stone: Int
    public var food: Int
    public var timber: Int
    public init(stone: Int = 0, food: Int = 0, timber: Int = 0) {
        self.stone = stone; self.food = food; self.timber = timber
    }
    public subscript(_ resource: Resource) -> Int {
        get { switch resource { case .stone: return stone; case .food: return food; case .timber: return timber } }
        set { switch resource { case .stone: stone = newValue; case .food: food = newValue; case .timber: timber = newValue } }
    }
    public func meets(_ order: Resources) -> Bool {
        stone >= order.stone && food >= order.food && timber >= order.timber
    }
    public var summary: String {
        Resource.allCases.filter { self[$0] > 0 }.map { "\(self[$0]) \($0.rawValue)" }.joined(separator: " · ")
    }
}

public struct Tile: Codable, Equatable, Sendable {
    public var terrain: Terrain
    public var building: Piece?
    public var infrastructure: Piece?
    public var inheritedInfrastructure: Bool
    public init(terrain: Terrain = .grass, building: Piece? = nil, infrastructure: Piece? = nil,
                inheritedInfrastructure: Bool = false) {
        self.terrain = terrain; self.building = building; self.infrastructure = infrastructure
        self.inheritedInfrastructure = inheritedInfrastructure
    }
}

public struct Board: Codable, Equatable, Sendable {
    public static let side = 7
    public var tiles: [Tile]
    public var depot: Position
    public init(tiles: [Tile] = Array(repeating: Tile(), count: side * side),
                depot: Position = Position(row: 6, col: 3)) {
        self.tiles = tiles; self.depot = depot
    }
    public static var positions: [Position] {
        (0..<side).flatMap { row in (0..<side).map { Position(row: row, col: $0) } }
    }
    public func contains(_ position: Position) -> Bool {
        position.row >= 0 && position.row < Self.side && position.col >= 0 && position.col < Self.side
    }
    public subscript(_ position: Position) -> Tile {
        get { tiles[position.row * Self.side + position.col] }
        set { tiles[position.row * Self.side + position.col] = newValue }
    }
    public static var initial: Board { Balance.levels[0].initialBoard }

}

public struct ProducerResult: Codable, Equatable, Identifiable, Sendable {
    public var position: Position
    public var piece: Piece
    public var connected: Bool
    public var valid: Bool
    public var resource: Resource?
    public var amount: Int
    /// Starts at the producer, follows built roads or bridges, and ends at the depot.
    public var route: [Position]
    public var reason: String
    public var worked: Bool { connected && valid }
    public var id: Position { position }
}

public struct Evaluation: Codable, Equatable, Sendable {
    public var totals: Resources
    public var producers: [ProducerResult]
    public var meetsOrder: Bool
    public var revision: Int
    public var disconnectedCount: Int { producers.filter { !$0.connected }.count }
    public var successfulProducers: [ProducerResult] { producers.filter { $0.worked && $0.amount > 0 } }
}

public struct GameState: Codable, Equatable, Sendable {
    public var levelIndex: Int
    public var board: Board
    public var budget: Int
    public var evaluation: Evaluation?
    public var tutorialProgress: Int
    public var revision: Int
    public init(levelIndex: Int = 0, board: Board? = nil, budget: Int? = nil,
                evaluation: Evaluation? = nil, tutorialProgress: Int = 0, revision: Int = 0) {
        self.levelIndex = levelIndex
        self.board = board ?? Balance.levels[levelIndex].initialBoard
        self.budget = budget ?? Balance.levels[levelIndex].budget
        self.evaluation = evaluation; self.tutorialProgress = tutorialProgress; self.revision = revision
    }
    public var level: LevelDefinition { Balance.levels[levelIndex] }
    public var spentCoins: Int { level.budget - budget }
    public var canAdvance: Bool { evaluation?.meetsOrder == true && evaluation?.revision == revision }
    public func count(of piece: Piece) -> Int {
        board.tiles.filter { $0.building == piece || $0.infrastructure == piece }.count
    }
}

public enum GameAction: Codable, Equatable, Sendable {
    case place(Piece, Position)
    case remove(Position)
    case clearWoodland(Position)
}

public struct GameError: LocalizedError, Equatable, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
