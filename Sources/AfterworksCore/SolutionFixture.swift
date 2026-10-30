import Foundation

/// Ordinary optimal player actions, also driven through real touches by the native tests.
public enum SolutionFixture {
    private static func p(_ row: Int, _ col: Int) -> Position { Position(row: row, col: col) }
    private static func roads(_ points: [(Int, Int)]) -> [GameAction] { points.map { .place(.road, p($0.0, $0.1)) } }
    public static let primary: [[GameAction]] = [
        roads([(5,3)]) + [.place(.orchard, p(4,3))],
        roads([(5,3),(4,3)]) + [.place(.orchard, p(3,3))],
        roads([(5,3)]) + [.place(.orchard, p(5,2)), .place(.orchard, p(5,4))],
        roads([(5,3),(4,3)]) + [.place(.quarry, p(4,2)), .place(.orchard, p(5,4))],
        roads([(5,3),(4,3),(3,3)]) + [.place(.lumberCamp, p(3,2)), .place(.lumberCamp, p(3,4))],
        roads([(5,3),(3,3)]) + [.place(.bridge, p(4,3)), .place(.orchard, p(3,2)), .place(.orchard, p(3,4))],
        roads([(5,3),(3,3)]) + [.place(.bridge, p(4,3)), .place(.quarry, p(2,3)), .place(.orchard, p(3,2))],
        roads([(5,3),(4,3),(3,3)]) + [.place(.field, p(3,2)), .place(.field, p(3,4)), .place(.field, p(2,3))],
        roads([(5,3),(4,3),(3,3)]) + [.place(.reservoir, p(2,3)), .place(.field, p(3,2)), .place(.field, p(3,4))],
        [.clearWoodland(p(4,3))] + roads([(5,3),(4,3),(3,3)]) + [.place(.lumberCamp, p(3,2)), .place(.lumberCamp, p(3,4)), .place(.field, p(4,2)), .place(.field, p(4,4))],
        roads([(5,3),(3,3),(2,3)]) + [.place(.bridge, p(4,3)), .place(.quarry, p(3,2)), .place(.lumberCamp, p(3,4)), .place(.reservoir, p(1,3)), .place(.field, p(2,2)), .place(.field, p(2,4))],
        [.clearWoodland(p(4,3))] + roads([(5,3),(4,3),(3,3),(2,3),(2,2),(2,4)]) + [.place(.bridge, p(3,4)), .place(.quarry, p(2,1)), .place(.lumberCamp, p(2,5)), .place(.reservoir, p(1,4)), .place(.field, p(1,2)), .place(.field, p(1,3)), .place(.field, p(3,5))]
    ]

    public static func actions(forLevel index: Int) -> [GameAction] { primary.indices.contains(index) ? primary[index] : [] }
    public static func completed() throws -> Campaign {
        var campaign = Campaign.new
        for index in Balance.levels.indices {
            for action in primary[index] { try campaign.apply(action) }
            campaign.dispatch()
            if index < Balance.levels.count - 1 { try campaign.advance() }
        }
        return campaign
    }
}
