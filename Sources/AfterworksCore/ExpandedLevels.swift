import Foundation

enum ExpandedLevels {
    struct Entry: Decodable {
        let title: String
        let terrain: String
        let solution: String
        let order: [Int]
        let limits: [Int]
        let minimum: Int
        let budget: Int
        let twoStar: Int
        let band: Int
        let seed: UInt64
        let networks: Int
    }
    static let entries = try! JSONDecoder().decode([Entry].self, from: Data(ExpandedCatalogData.json.utf8))
    private static let terrains: [Character: Terrain] = ["g": .grass, "s": .stone, "w": .water, "t": .woodland, "m": .wetland, "c": .cliff]
    private static let pieces: [Character: Piece] = ["q": .quarry, "o": .orchard, "l": .lumberCamp, "f": .field, "v": .reservoir, "r": .road, "b": .bridge]
    private static let limitOrder: [Piece] = [.quarry, .orchard, .lumberCamp, .field, .reservoir, .bridge]
    private static let subtitles = [
        "Find the shared route through a new island.",
        "Compare crossings and competing production sites.",
        "Open a route while preserving working woodland.",
        "Fit three fields around one connected reservoir.",
        "Balance every resource across a compact island."
    ]
    private static let hints = [
        "Share one connected reservoir between all three fields. Keep woodland beside the camp, and compare quarry access before clearing a route.",
        "Use both wetland fields and an orchard for food. Share the crossing between two quarries and the camp; a bridge costs as much as three roads.",
        "Fit three fields within two steps of one connected reservoir. Share the quarry roads, clear only the route you need, and preserve woodland for the camp.",
        "Both camps need surviving woodland, while three fields need the reservoir bonus. Plan those dependencies before connecting the two quarries.",
        "Plan the reservoir and three fields together, preserve woodland for both camps, then compare the three quarry routes. Every shared road saves a coin."
    ]

    static let levels: [LevelDefinition] = entries.enumerated().map { offset, entry in
        let limits = Dictionary(uniqueKeysWithValues: zip(limitOrder, entry.limits).filter { $0.1 > 0 })
        let available = [.road, .bridge] + Piece.allCases.filter { !$0.isInfrastructure && limits[$0] != nil }
        return LevelDefinition(index: offset + 12, title: entry.title, subtitle: subtitles[entry.band], hint: hints[entry.band],
                               order: Resources(stone: entry.order[0], food: entry.order[1], timber: entry.order[2]),
                               budget: entry.budget, availablePieces: available, pieceLimits: limits,
                               initialBoard: Board(tiles: entry.terrain.map { Tile(terrain: terrains[$0]!) }),
                               minimumCoins: entry.minimum, twoStarCoins: entry.twoStar)
    }

    static let solutions: [[GameAction]] = entries.map { entry in
        entry.solution.split(separator: " ").map { token in
            let index = Int(token.dropFirst())!
            let position = Position(row: index / Board.side, col: index % Board.side)
            if token.first == "x" { return .clearWoodland(position) }
            return .place(pieces[token.first!]!, position)
        }
    }
}
