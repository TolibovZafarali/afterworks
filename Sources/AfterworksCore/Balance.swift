import Foundation

public struct PieceDefinition: Sendable {
    public var title: String
    public var cost: Int
    public var output: Int
    public var resource: Resource?
    public var limit: Int
    public var rule: String
}

public struct LevelDefinition: Identifiable, Sendable {
    public var index: Int
    public var id: Int { index + 1 }
    public var title: String
    public var subtitle: String
    public var hint: String
    public var order: Resources
    public var budget: Int
    public var availablePieces: [Piece]
    public var pieceLimits: [Piece: Int]
    public var initialBoard: Board
    public var minimumCoins: Int
    public var twoStarCoins: Int
    public func limit(for piece: Piece) -> Int {
        availablePieces.contains(piece) ? (pieceLimits[piece] ?? Balance.definition(for: piece).limit) : 0
    }
    public func stars(forSpent coins: Int) -> Int {
        guard coins >= 0 && coins <= budget else { return 0 }
        return coins <= minimumCoins ? 3 : coins <= twoStarCoins ? 2 : 1
    }
}

public enum Balance {
    public static let clearingCost = 2
    public static let fieldBonus = 2
    public static let reservoirRadius = 2
    public static let saveVersion = 2

    public static func definition(for piece: Piece) -> PieceDefinition {
        switch piece {
        case .quarry:
            return PieceDefinition(title: "Quarry", cost: 5, output: 4, resource: .stone, limit: 2,
                                   rule: "On stone ground. Connect through roads to deliver 4 stone.")
        case .orchard:
            return PieceDefinition(title: "Orchard", cost: 4, output: 3, resource: .food, limit: 3,
                                   rule: "On meadow. Connect through roads to deliver 3 food.")
        case .lumberCamp:
            return PieceDefinition(title: "Lumber camp", cost: 4, output: 4, resource: .timber, limit: 3,
                                   rule: "On dry ground beside woodland. Connect through roads for 4 timber. Woodland remains.")
        case .field:
            return PieceDefinition(title: "Field", cost: 3, output: 3, resource: .food, limit: 4,
                                   rule: "Meadow beside a lake, or wetland. 3 food; +2 on wetland or within 2 steps of a connected reservoir. Bonuses do not stack.")
        case .reservoir:
            return PieceDefinition(title: "Reservoir", cost: 4, output: 0, resource: nil, limit: 1,
                                   rule: "Dry ground beside a lake. Connect through roads to give fields within 2 orthogonal steps +2 food.")
        case .road:
            return PieceDefinition(title: "Road", cost: 1, output: 0, resource: nil, limit: 49,
                                   rule: "Meadow or stone. Joins along edges. Every producer needs a route containing at least one road before the depot.")
        case .bridge:
            return PieceDefinition(title: "Bridge", cost: 3, output: 0, resource: nil, limit: 8,
                                   rule: "Crosses lake or wetland. Join it to a road network reaching the depot.")
        }
    }

    public static let levels: [LevelDefinition] = AuthoredLevels.make()
}
