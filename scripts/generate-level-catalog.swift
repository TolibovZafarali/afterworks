import Foundation

/// Rebuild with: swiftc -O Sources/AfterworksCore/*.swift scripts/generate-level-catalog.swift -o /tmp/afterworks-catalog
/// Run the binary from the repository root. It writes only the appended catalog.
@main
struct CatalogBuilder {
    struct Random {
        var state: UInt64
        mutating func next(_ upper: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 32) % UInt64(upper))
        }
        mutating func shuffled<T>(_ values: [T]) -> [T] {
            var result = values
            if result.count > 1 {
                for i in stride(from: result.count - 1, through: 1, by: -1) { result.swapAt(i, next(i + 1)) }
            }
            return result
        }
    }
    struct Recipe: Codable { let band: Int; let seed: UInt64 }
    struct Entry: Codable {
        var title: String
        var terrain: String
        var solution: String
        var order: [Int]
        var limits: [Int]
        var minimum: Int
        var budget: Int
        var twoStar: Int
        var band: Int
        var seed: UInt64
        var networks: Int
    }
    static let producerOrder: [Piece] = [.quarry, .orchard, .lumberCamp, .field, .reservoir, .bridge]
    static let terrainCode: [Terrain: Character] = [.grass: "g", .stone: "s", .water: "w", .woodland: "t", .wetland: "m", .cliff: "c"]
    static let actionCode: [Piece: String] = [.quarry: "q", .orchard: "o", .lumberCamp: "l", .field: "f", .reservoir: "v", .road: "r", .bridge: "b"]
    static let bandNames = ["Shared shores", "River country", "Working woodland", "Water gardens", "Master islands"]
    static let titles = [
        ["Pebble", "Willow", "Copper", "Heron", "Cedar", "Juniper", "Alder", "Plover", "Birch", "Hazel", "Otter", "Sparrow"],
        ["Tide", "Ripple", "Drift", "Reed", "Channel", "Estuary", "Delta", "Current", "Pool", "Gull", "Marsh", "Ferry", "Shoal", "Salmon", "Inlet", "Sail"],
        ["Pine", "Elm", "Ash", "Aspen", "Oak", "Fir", "Larch", "Maple", "Spruce", "Beech", "Rowan", "Holly", "Laurel", "Moss", "Fern", "Bramble", "Acorn", "Grove", "Bark", "Forest"],
        ["Rain", "Dew", "Spring", "Lotus", "Lily", "Iris", "Sedge", "Rush", "Brook", "Cress", "Bloom", "Petal", "Mist", "Cloud", "Terrace", "Harvest", "Meadow", "Clover", "Orchid", "Willow"],
        ["Summit", "Compass", "Beacon", "Horizon", "Aurora", "Meridian", "Polaris", "Solstice", "Equinox", "Zenith", "Opal", "Onyx", "Jasper", "Amber", "Pearl", "Sapphire", "Topaz", "Ruby", "Emerald", "Hundredth"]
    ]

    static func main() throws {
        let recipeOption = CommandLine.arguments.firstIndex(of: "--recipe").map { CommandLine.arguments[$0 + 1] }
        let defaultRecipe = "scripts/level-catalog-recipe.json"
        let recipePath = recipeOption ?? (CommandLine.arguments.count == 1 || CommandLine.arguments.contains("--check") ? defaultRecipe : nil)
        if let recipePath, FileManager.default.fileExists(atPath: recipePath) {
            let recipe = try JSONDecoder().decode([Recipe].self, from: Data(contentsOf: URL(fileURLWithPath: recipePath)))
            var entries: [Entry] = []
            for item in recipe {
                let ordinal = entries.filter { $0.band == item.band }.count
                let entry = try certifiedEntry(seed: item.seed, band: item.band, ordinal: ordinal)
                entries.append(entry)
                print("Rebuilt seed \(item.seed): \(entry.minimum) coins, \(entry.networks) networks")
                fflush(stdout)
            }
            try write(entries)
            print("Reproduced \(entries.count) certified catalog entries.")
            return
        }
        if CommandLine.arguments.dropFirst().first == "--merge" {
            let entries = try CommandLine.arguments.dropFirst(2).flatMap { path in
                try JSONDecoder().decode([Entry].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
            }
            guard entries.count == 88 else { throw GameError("A complete catalog needs 88 appended entries.") }
            var signatures = Set(AuthoredLevels.make().map { topology($0.initialBoard) })
            for entry in entries {
                let board = Board(tiles: entry.terrain.map { code in Tile(terrain: terrainCode.first(where: { $0.value == code })!.key) })
                guard signatures.insert(topology(board)).inserted else { throw GameError("Duplicate island footprint at seed \(entry.seed).") }
            }
            try write(entries)
            print("Merged 88 globally unique island topologies.")
            return
        }
        let selectedBand = CommandLine.arguments.firstIndex(of: "--band").flatMap { Int(CommandLine.arguments[$0 + 1]) }
        var entries: [Entry] = []
        if let appendIndex = CommandLine.arguments.firstIndex(of: "--append-from") {
            entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[appendIndex + 1])))
        } else if CommandLine.arguments.contains("--resume") {
            entries = try JSONDecoder().decode([Entry].self, from: Data(ExpandedCatalogData.json.utf8))
        }
        var seen: Set<String> = Set(AuthoredLevels.make().map { topology($0.initialBoard) })
        for entry in entries {
            let board = Board(tiles: entry.terrain.map { code in Tile(terrain: terrainCode.first(where: { $0.value == code })!.key) })
            seen.insert(topology(board))
        }
        var seed: UInt64 = entries.last.map { $0.seed + 1 } ?? (2026103001 + UInt64(selectedBand ?? 0) * 100000)
        if let startIndex = CommandLine.arguments.firstIndex(of: "--start-seed") { seed = UInt64(CommandLine.arguments[startIndex + 1])! }
        let counts = [12, 16, 20, 20, 20]
        for band in 0..<counts.count where selectedBand == nil || selectedBand == band {
            var attempts = 0
            while entries.filter({ $0.band == band }).count < counts[band] {
                let ordinal = entries.filter { $0.band == band }.count
                defer { seed += 1; attempts += 1 }
                guard attempts < 100_000 else { throw GameError("Could not fill band \(band).") }
                guard var level = candidate(seed: seed, band: band, ordinal: ordinal) else { continue }
                let signature = topology(level.initialBoard)
                guard !seen.contains(signature) else { continue }
                guard let solved = try? MinimumCostProof.solve(level: level, maximumCoins: level.minimumCoins, networkLimit: 20_000) else { continue }
                let placed = solved.actions.compactMap { action -> Piece? in if case let .place(piece, _) = action { return piece }; return nil }
                let roads = placed.filter { $0.isInfrastructure }.count
                let bridges = placed.filter { $0 == .bridge }.count
                let clears = solved.actions.filter { if case .clearWoodland = $0 { return true }; return false }.count
                guard roads >= 4 + band, bridges >= (band == 4 ? 2 : 1), clears >= 1,
                      solved.spentCoins >= [32, 35, 39, 44, 49][band],
                      band == 1 || placed.contains(.reservoir) else { continue }
                let title = titles[band][ordinal] + [" Reach", " Crossing", " Vale", " Gardens", " Island"][band]
                level.minimumCoins = solved.spentCoins
                let allowance = [9, 9, 8, 8, 7][band]
                let entry = Entry(title: title,
                                  terrain: String(level.initialBoard.tiles.map { terrainCode[$0.terrain]! }),
                                  solution: encode(solved.actions),
                                  order: [level.order.stone, level.order.food, level.order.timber],
                                  limits: producerOrder.map { level.limit(for: $0) },
                                  minimum: solved.spentCoins, budget: solved.spentCoins + allowance,
                                  twoStar: solved.spentCoins + max(2, allowance / 2), band: band,
                                  seed: seed, networks: solved.checkedNetworks)
                entries.append(entry)
                seen.insert(signature)
                print("Level \(entries.count + 12): \(entry.title), \(entry.minimum) coins, \(roads) route tiles, \(solved.checkedNetworks) networks, seed \(seed)")
                fflush(stdout)
            }
        }
        try write(entries)
        print("Verified \(entries.count) appended levels with unique island topologies.")
    }

    static func certifiedEntry(seed: UInt64, band: Int, ordinal: Int) throws -> Entry {
        guard let level = candidate(seed: seed, band: band, ordinal: ordinal),
              let solved = try MinimumCostProof.solve(level: level, maximumCoins: level.minimumCoins, networkLimit: 20_000) else {
            throw GameError("The catalog recipe failed at seed \(seed).")
        }
        let title = titles[band][ordinal] + [" Reach", " Crossing", " Vale", " Gardens", " Island"][band]
        let allowance = [9, 9, 8, 8, 7][band]
        return Entry(title: title, terrain: String(level.initialBoard.tiles.map { terrainCode[$0.terrain]! }),
                     solution: encode(solved.actions), order: [level.order.stone, level.order.food, level.order.timber],
                     limits: producerOrder.map { level.limit(for: $0) }, minimum: solved.spentCoins,
                     budget: solved.spentCoins + allowance, twoStar: solved.spentCoins + max(2, allowance / 2),
                     band: band, seed: seed, networks: solved.checkedNetworks)
    }

    static func candidate(seed: UInt64, band: Int, ordinal: Int) -> LevelDefinition? {
        var random = Random(state: seed)
        let fortified = band == 4 || (band == 3 && seed >= 2026406000)
        let depot = Position(row: 6, col: 3)
        let first = Position(row: 5, col: 3)
        let routeCount = 6 + band + random.next(2)
        let neck = Set([Position(row: 5, col: 2), Position(row: 5, col: 4), Position(row: 4, col: 2), Position(row: 4, col: 4)])
        var route: Set<Position> = fortified ? [first, Position(row: 4, col: 3), Position(row: 3, col: 3)] : [first]
        for _ in route.count..<routeCount {
            let frontier = Board.positions.filter { p in
                p.row > 0 && p.row < 6 && p.col > 0 && p.col < 6 && !route.contains(p) &&
                (!fortified || !neck.contains(p)) && p != depot && p.neighbors.filter({ route.contains($0) }).count == 1
            }
            guard let chosen = random.shuffled(frontier).first else { return nil }
            route.insert(chosen)
        }
        var board = Board(tiles: Array(repeating: Tile(terrain: .cliff), count: 49), depot: depot)
        for p in Board.positions where p.row == 0 || p.col == 0 || p.col == 6 || p.row == 6 { board[p].terrain = .water }
        board[depot].terrain = .grass
        for p in route { board[p].terrain = .grass }
        var occupied = route.union([depot])
        var producers: [(Position, Piece)] = []
        var supports: Set<Position> = []
        let fringe = random.shuffled(Board.positions.filter { p in
            p != depot && !route.contains(p) && p.row < 6 &&
            (fortified ? !neck.contains(p) : p.row > 0 && p.col > 0 && p.col < 6) &&
            p.neighbors.contains(where: route.contains)
        })
        func freeNeighbors(_ p: Position) -> [Position] { p.neighbors.filter { !occupied.contains($0) && !supports.contains($0) && (!fortified || !neck.contains($0)) } }
        func add(_ piece: Piece, at p: Position, terrain: Terrain) {
            occupied.insert(p); board[p].terrain = terrain; producers.append((p, piece))
        }
        if band != 1 {
            // All three ordinary fields must share one connected reservoir. Their
            // shoreline sites and the reservoir compete with the routing space.
            var irrigation: (Position, [Position], Set<Position>)?
            for reservoir in fringe {
                let nearby = random.shuffled(fringe.filter { $0 != reservoir && $0.distance(to: reservoir) <= 2 })
                guard nearby.count >= 3 else { continue }
                for firstIndex in nearby.indices {
                    guard firstIndex + 2 < nearby.count else { continue }
                    let fields = Array(nearby[firstIndex..<(firstIndex + 3)])
                    let forbidden = occupied.union(fields).union([reservoir]).union(fortified ? neck : [])
                    var lakes: Set<Position> = []
                    var valid = true
                    for p in fields + [reservoir] {
                        if p.neighbors.contains(where: { lakes.contains($0) }) { continue }
                        guard let lake = random.shuffled(p.neighbors.filter { !forbidden.contains($0) }).first else { valid = false; break }
                        lakes.insert(lake)
                    }
                    if valid { irrigation = (reservoir, fields, lakes); break }
                }
                if irrigation != nil { break }
            }
            guard let irrigation else { return nil }
            add(.reservoir, at: irrigation.0, terrain: .grass)
            for p in irrigation.1 { add(.field, at: p, terrain: .grass) }
            for p in irrigation.2 { board[p].terrain = .water; supports.insert(p) }
        } else {
            for p in fringe.filter({ !occupied.contains($0) }).prefix(2) { add(.field, at: p, terrain: .wetland) }
            if producers.count != 2 { return nil }
        }
        let quarryCount = band == 0 ? 1 : band == 4 ? 3 : 2
        let campCount = band >= 3 ? 2 : 1
        for _ in 0..<campCount {
            guard let camp = fringe.first(where: { !occupied.contains($0) && !supports.contains($0) && !freeNeighbors($0).isEmpty }) else { return nil }
            guard let wood = random.shuffled(freeNeighbors(camp)).first else { return nil }
            add(.lumberCamp, at: camp, terrain: .grass)
            board[wood].terrain = .woodland; supports.insert(wood)
        }
        for _ in 0..<quarryCount {
            guard let p = fringe.first(where: { !occupied.contains($0) && !supports.contains($0) }) else { return nil }
            add(.quarry, at: p, terrain: .stone)
        }
        if band == 1 {
            guard let p = fringe.first(where: { !occupied.contains($0) && !supports.contains($0) }) else { return nil }
            add(.orchard, at: p, terrain: .grass)
        }
        // Alternative dry sites create real choices for quarry placement, shared
        // roads, and cheaper access; the exact solver selects the best layout.
        let decoys = random.shuffled(Board.positions.filter { p in
            !occupied.contains(p) && !supports.contains(p) && p.row > 0 && p.row < 6 && p.col > 0 && p.col < 6 &&
            (!fortified || !neck.contains(p)) && p.neighbors.contains(where: { occupied.contains($0) })
        }).prefix(fortified ? 2 : 2 + band / 2)
        for p in decoys { board[p].terrain = random.next(3) == 0 ? .stone : .grass }
        let routeOrder = random.shuffled(route.sorted().filter { $0 != first })
        let bridgeCount = fortified ? 2 : 1
        guard routeOrder.count >= bridgeCount + 1 else { return nil }
        if fortified {
            let crossing = Position(row: 4, col: 3)
            let clearing = Position(row: 3, col: 3)
            board[crossing].terrain = .water
            board[clearing].terrain = .woodland
            guard let second = routeOrder.first(where: { $0 != crossing && $0 != clearing }) else { return nil }
            board[second].terrain = .water
        } else {
            for p in routeOrder.prefix(bridgeCount) { board[p].terrain = .water }
            board[routeOrder[bridgeCount]].terrain = .woodland
        }
        var actions: [GameAction] = []
        for p in route.sorted() {
            if board[p].terrain == .woodland { actions.append(.clearWoodland(p)) }
            actions.append(.place(board[p].terrain == .water ? .bridge : .road, p))
        }
        for (p, piece) in producers { actions.append(.place(piece, p)) }
        var solved = board
        var cost = 0
        for action in actions {
            switch action {
            case let .clearWoodland(p): solved[p].terrain = .grass; cost += Balance.clearingCost
            case let .place(piece, p):
                if Rules.terrainError(piece, at: p, on: solved) != nil { return nil }
                if piece.isInfrastructure { solved[p].infrastructure = piece } else { solved[p].building = piece }
                cost += Balance.definition(for: piece).cost
            default: return nil
            }
        }
        let order = Rules.evaluate(board: solved, order: Resources()).totals
        guard order.food > 0, order.stone == quarryCount * 4, order.timber == campCount * 4,
              band == 1 || order.food == 15 else { return nil }
        // Removing a redundant route tile gives another legal upper bound. A
        // completed plan below the band's floor can be rejected without searching.
        for p in route.sorted() {
            let before = solved[p]
            guard let piece = before.infrastructure else { continue }
            solved[p].infrastructure = nil
            var refund = Balance.definition(for: piece).cost
            if board[p].terrain == .woodland {
                solved[p].terrain = .woodland
                refund += Balance.clearingCost
            }
            if Rules.evaluate(board: solved, order: order).meetsOrder { cost -= refund }
            else { solved[p] = before }
        }
        guard cost >= [32, 35, 39, 44, 49][band] else { return nil }
        var limits: [Piece: Int] = [:]
        for (_, piece) in producers { limits[piece, default: 0] += 1 }
        limits[.bridge] = max(2, bridgeCount + 1)
        let available = [.road, .bridge] + Piece.allCases.filter { !$0.isInfrastructure && limits[$0] != nil }
        return LevelDefinition(index: 12, title: "Candidate", subtitle: bandNames[band], hint: "",
                               order: order, budget: cost + 10, availablePieces: available, pieceLimits: limits,
                               initialBoard: board, minimumCoins: cost, twoStarCoins: cost + 4)
    }

    static func topology(_ board: Board) -> String {
        // Ignore water/rock colors: the usable dry/wetland footprint itself must
        // differ after every rotation and reflection, not merely its decoration.
        let usable = Set(Board.positions.filter { ![Terrain.cliff, .water].contains(board[$0].terrain) })
        return (0..<8).map { transform in
            var cells = Array(repeating: Character("."), count: 49)
            for p in usable {
                var r = p.row, c = p.col
                if transform >= 4 { c = 6 - c }
                for _ in 0..<(transform % 4) { let old = r; r = c; c = 6 - old }
                cells[r * 7 + c] = "x"
            }
            return String(cells)
        }.min()!
    }
    static func encode(_ actions: [GameAction]) -> String {
        actions.map { action in
            switch action {
            case let .place(piece, p): return "\(actionCode[piece]!)\(p.id)"
            case let .clearWoodland(p): return "x\(p.id)"
            case .remove: fatalError("An optimal fixture never removes a piece.")
            }
        }.joined(separator: " ")
    }
    static func write(_ entries: [Entry]) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        if let outputIndex = CommandLine.arguments.firstIndex(of: "--output") {
            try encoder.encode(entries).write(to: URL(fileURLWithPath: CommandLine.arguments[outputIndex + 1]), options: .atomic)
            return
        }
        let lines = try entries.map { String(data: try encoder.encode($0), encoding: .utf8)! }.joined(separator: ",\n")
        let source = """
        import Foundation

        // Fixed catalog data. Rebuild and certify with scripts/generate-level-catalog.swift.
        enum ExpandedCatalogData {
            static let json = #\"\"\"
        [
        \(lines)
        ]
        \"\"\"#
        }

        """
        let path = "Sources/AfterworksCore/ExpandedCatalogData.swift"
        if CommandLine.arguments.contains("--check") {
            guard try String(contentsOfFile: path, encoding: .utf8) == source else { throw GameError("The bundled catalog differs from the deterministic rebuild.") }
        } else {
            try source.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}
