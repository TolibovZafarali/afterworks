import Foundation

/// Reproducible ordinary player actions. Coordinates are zero-based; labels use A–G and 1–7.
public enum SolutionFixture {
    private static func p(_ row: Int, _ col: Int) -> Position { Position(row: row, col: col) }
    public static let primary: [[GameAction]] = [
        [
            .place(.road, p(5, 3)), .place(.road, p(4, 3)), .place(.road, p(4, 2)),
            .place(.road, p(3, 3)), .place(.road, p(2, 3)),
            .place(.quarry, p(4, 1)), .place(.orchard, p(2, 2)), .place(.orchard, p(4, 4))
        ],
        [
            .place(.road, p(3, 2)), .place(.road, p(5, 2)), .place(.road, p(5, 0)),
            .place(.road, p(6, 0)), .place(.road, p(6, 1)), .place(.road, p(6, 2)),
            .place(.reservoir, p(3, 1)), .place(.field, p(5, 1)), .place(.field, p(4, 0)),
            .place(.lumberCamp, p(3, 4))
        ],
        [
            .place(.road, p(5, 4)), .place(.road, p(5, 5)), .place(.road, p(1, 3)),
            .place(.quarry, p(4, 5)), .place(.field, p(3, 1)), .place(.field, p(5, 1)),
            .place(.lumberCamp, p(1, 2)), .place(.lumberCamp, p(3, 4))
        ]
    ]

    public static let alternative: [[GameAction]] = primary.map { era in
        era.map { action in
            switch action {
            case let .place(piece, position):
                return .place(piece, Position(row: position.row, col: Board.side - 1 - position.col))
            case let .remove(position):
                return .remove(Position(row: position.row, col: Board.side - 1 - position.col))
            case let .clearWoodland(position):
                return .clearWoodland(Position(row: position.row, col: Board.side - 1 - position.col))
            }
        }
    }

    public static func actions(forEra eraIndex: Int, variant: Int = 0) -> [GameAction] {
        guard primary.indices.contains(eraIndex) else { return [] }
        return (variant == 0 ? primary : alternative)[eraIndex]
    }

    public static func completed(variant: Int = 0) throws -> Journey {
        var journey = Journey.new
        for era in (variant == 0 ? primary : alternative) {
            for action in era { try journey.apply(action) }
            journey.dispatch()
            try journey.advance()
        }
        return journey
    }
}
