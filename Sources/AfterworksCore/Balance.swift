import Foundation

public struct PieceDefinition: Sendable {
    public var title: String
    public var cost: Int
    public var output: Int
    public var resource: Resource?
    public var limit: Int
    public var rule: String
    public var legacy: String
}

public struct Scenario: Sendable {
    public var title: String
    public var subtitle: String
    public var order: Resources
    public var budget: Int
    public var availablePieces: [Piece]
    public var forecast: String
}

public enum Balance {
    public static let clearingCost = 2
    public static let inheritedRemovalCost = 1
    public static let fieldBonus = 2
    public static let reservoirRadius = 2
    public static let saveVersion = 1

    public static func definition(for piece: Piece) -> PieceDefinition {
        switch piece {
        case .quarry:
            return PieceDefinition(title: "Quarry", cost: 5, output: 4, resource: .stone, limit: 2,
                                   rule: "On stone ground. Connect to deliver 4 stone.", legacy: "Becomes a lake at this tile.")
        case .orchard:
            return PieceDefinition(title: "Orchard", cost: 4, output: 3, resource: .food, limit: 3,
                                   rule: "On meadow. Connect to deliver 3 food.", legacy: "Becomes woodland at this tile.")
        case .lumberCamp:
            return PieceDefinition(title: "Lumber camp", cost: 4, output: 4, resource: .timber, limit: 3,
                                   rule: "On dry ground beside woodland. Delivers 4 timber; woodland remains.", legacy: "Leaves usable meadow; nearby woodland remains.")
        case .field:
            return PieceDefinition(title: "Field", cost: 3, output: 3, resource: .food, limit: 4,
                                   rule: "On meadow beside a lake, or on wetland. 3 food; +2 on wetland or within 2 steps of a connected reservoir. Bonuses do not stack.", legacy: "Leaves meadow, or preserves its underlying wetland.")
        case .reservoir:
            return PieceDefinition(title: "Reservoir", cost: 4, output: 0, resource: nil, limit: 2,
                                   rule: "On dry ground beside a lake. Connect to give fields within 2 orthogonal steps +2 food.", legacy: "Becomes wetland at this tile.")
        case .road:
            return PieceDefinition(title: "Road", cost: 1, output: 0, resource: nil, limit: 49,
                                   rule: "On meadow or stone. Orthogonal connections only; buildings do not carry roads.", legacy: "Remains as a free old route. Removing an old route costs 1.")
        case .bridge:
            return PieceDefinition(title: "Bridge", cost: 3, output: 0, resource: nil, limit: 8,
                                   rule: "Across lake or wetland. Connects exactly like a road.", legacy: "Remains as an old bridge over the same terrain. Removing it costs 1.")
        }
    }

    public static let scenarios: [Scenario] = [
        Scenario(title: "First foundations", subtitle: "Establish the settlement", order: Resources(stone: 4, food: 6), budget: 22,
                 availablePieces: [.road, .quarry, .orchard, .bridge],
                 forecast: "Next: 10 food + 4 timber. Your quarries become lakes for fields. Your orchards become woodland for lumber camps. The depot stays here."),
        Scenario(title: "What remains", subtitle: "Use what you left behind", order: Resources(food: 10, timber: 4), budget: 26,
                 availablePieces: [.road, .lumberCamp, .field, .reservoir, .bridge, .orchard, .quarry],
                 forecast: "Next: 4 stone + 8 food + 8 timber. Connected reservoirs leave wetland with +2 food for fields. Old routes and woodland remain. The depot stays here."),
        Scenario(title: "A lasting place", subtitle: "Combine the consequences", order: Resources(stone: 4, food: 8, timber: 8), budget: 26,
                 availablePieces: [.road, .quarry, .lumberCamp, .field, .reservoir, .orchard, .bridge],
                 forecast: "The final landscape is yours. Complete the order, then watch this settlement become a living island of lakes, woods and wetland.")
    ]
}
