import Foundation

enum AuthoredLevels {
    private static func p(_ row: Int, _ col: Int) -> Position { Position(row: row, col: col) }

    private static func board(sea: Bool = false, grass: [(Int, Int)], stone: [(Int, Int)] = [],
                              water: [(Int, Int)] = [], woods: [(Int, Int)] = [], wetland: [(Int, Int)] = []) -> Board {
        var board = Board(tiles: Array(repeating: Tile(terrain: sea ? .water : .cliff), count: 49))
        if !sea {
            for position in Board.positions where position.row == 0 || position.row == 6 || position.col == 0 || position.col == 6 {
                board[position].terrain = .water
            }
        }
        for (positions, terrain) in [(grass, Terrain.grass), (stone, .stone), (water, .water), (woods, .woodland), (wetland, .wetland)] {
            for (row, col) in positions { board[p(row, col)].terrain = terrain }
        }
        board[board.depot].terrain = .grass
        return board
    }

    static func make() -> [LevelDefinition] {
        let definitions: [(String, String, String, Resources, Int, [Piece], [Piece: Int], Board, Int, Int)] = [
            ("First delivery", "One orchard. One road.",
             "Place an orchard at D5 and a road at D6. Then Dispatch. Being beside the depot never connects a building by itself.",
             Resources(food: 3), 9, [.orchard, .road], [.orchard: 1],
             board(sea: true, grass: [(4,3),(5,3),(4,4),(5,4),(6,4)]), 5, 7),
            ("A little farther", "Give your goods a way home.",
             "Orchards need meadow. The pale stone strip makes a useful road: D6, D5, then an orchard at D4.",
             Resources(food: 3), 10, [.orchard, .road], [.orchard: 1],
             board(sea: true, grass: [(3,3),(3,4),(4,4)], stone: [(5,3),(4,3),(5,4),(5,5)]), 6, 8),
            ("Better together", "Two orchards, one shared route.",
             "A road can serve several buildings. Try the central tile D6 and orchards on either side.",
             Resources(food: 6), 14, [.road, .orchard], [.orchard: 2],
             board(sea: true, grass: [(5,2),(5,4),(4,2),(4,4)], stone: [(5,3),(4,3),(3,3)]), 9, 11),
            ("Stone & supper", "Fill an order with two resources.",
             "Quarries need stone. Compare the west and east rock sites, and let your orchard share the quarry's road.",
             Resources(stone: 4, food: 3), 17, [.road, .quarry, .orchard], [.quarry: 1, .orchard: 1],
             board(sea: true, grass: [(5,3),(4,3),(5,4),(4,4),(5,5)], stone: [(4,2),(4,5)]), 11, 14),
            ("At the wood's edge", "Bring timber from both groves.",
             "Camps sit beside woodland, not on it. Keep the woods intact and share a central road between the two camps.",
             Resources(timber: 8), 17, [.road, .lumberCamp], [.lumberCamp: 2],
             board(sea: true, grass: [(3,2),(3,4),(4,2),(4,4)], stone: [(5,3),(4,3),(3,3)], woods: [(3,1),(3,5)]), 11, 14),
            ("Across the blue", "A bridge joins the two shores.",
             "Roads cannot cross water. Put a bridge at D5, join it to roads on both shores, and connect two orchards.",
             Resources(food: 6), 19, [.road, .bridge, .orchard], [.orchard: 2, .bridge: 2],
             board(grass: [(3,2),(3,4),(2,2),(2,4)], stone: [(5,3),(3,3)], water: [(4,3)]), 13, 16),
            ("The price of a shortcut", "Compare a crossing with the long way.",
             "A bridge costs three roads. Choose a quarry site and compare the direct crossing with the dry eastern route.",
             Resources(stone: 4, food: 3), 21, [.road, .bridge, .quarry, .orchard], [.quarry: 1, .orchard: 1, .bridge: 2],
             board(grass: [(5,3),(3,2),(3,3),(5,4),(5,5),(4,5),(3,5),(3,4)], stone: [(2,3),(2,5)], water: [(4,3)]), 14, 17),
            ("Soft ground", "Grow more with the same three fields.",
             "Wetland fields deliver five food instead of three. Use both wetland patches and one lakeside field, all sharing a route.",
             Resources(food: 13), 18, [.road, .field, .bridge], [.field: 3, .bridge: 2],
             board(grass: [(2,3),(4,2),(4,4),(5,2)], stone: [(5,3),(4,3),(3,3)], water: [(2,2),(2,4)], wetland: [(3,2),(3,4)]), 12, 15),
            ("Water within reach", "Make two fields deliver ten food.",
             "Two ordinary fields give six food. Connect a reservoir within two orthogonal steps of both to reach ten.",
             Resources(food: 10), 20, [.road, .field, .reservoir, .bridge], [.field: 2, .reservoir: 1, .bridge: 2],
             board(grass: [(3,2),(3,4),(2,3),(4,2),(4,4)], stone: [(5,3),(4,3),(3,3)], water: [(2,2),(2,4)]), 13, 16),
            ("Room for everyone", "Clear a route, preserve the groves.",
             "Clearing woodland costs two coins and gives no timber. Open the central route, keep the side groves, and use wetland for food.",
             Resources(food: 10, timber: 8), 26, [.road, .lumberCamp, .field, .orchard, .bridge], [.lumberCamp: 2, .field: 2, .orchard: 2, .bridge: 2],
             board(grass: [(3,2),(3,4),(4,1),(4,5),(5,2),(5,4)], stone: [(5,3),(3,3)], woods: [(4,3),(3,1),(3,5)], wetland: [(4,2),(4,4)]), 19, 23),
            ("A full manifest", "Three resources across one crossing.",
             "Share the bridge and the central road. The two fields need a nearby connected reservoir; the camp still needs its woodland.",
             Resources(stone: 4, food: 10, timber: 4), 33, [.road, .bridge, .quarry, .lumberCamp, .field, .reservoir],
             [.quarry: 1, .lumberCamp: 1, .field: 2, .reservoir: 1, .bridge: 3],
             board(grass: [(2,3),(2,2),(2,4),(1,3),(3,4)], stone: [(5,3),(3,3),(3,2)],
                   water: [(4,3),(2,1),(2,5),(1,2),(1,4)], woods: [(3,5)]), 25, 29),
            ("Every coin counts", "Bring every lesson to one island.",
             "Keep one woodland for timber. Clear the central route, share its branches, irrigate two fields, and reach the wetland field with a bridge.",
             Resources(stone: 4, food: 15, timber: 4), 42, [.road, .bridge, .quarry, .lumberCamp, .field, .reservoir],
             [.quarry: 1, .lumberCamp: 1, .field: 3, .reservoir: 1, .bridge: 3],
             board(grass: [(2,3),(2,2),(2,4),(1,2),(1,3),(1,4),(2,5)], stone: [(5,3),(3,3),(2,1)],
                   water: [(3,2),(3,4)], woods: [(4,3),(2,6)], wetland: [(3,5)]), 33, 37)
        ]
        return definitions.enumerated().map { index, item in
            LevelDefinition(index: index, title: item.0, subtitle: item.1, hint: item.2, order: item.3,
                            budget: item.4, availablePieces: item.5, pieceLimits: item.6,
                            initialBoard: item.7, minimumCoins: item.8, twoStarCoins: item.9)
        }
    }
}
