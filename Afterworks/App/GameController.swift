import SwiftUI
import SpriteKit
import AfterworksCore

enum BuildTool: Equatable {
    case piece(Piece), inspect, remove, clear
}

enum GameSheet: String, Identifiable {
    case menu, guide, tiles, inspection, result, levels
    var id: String { rawValue }
}

struct LevelResult {
    var stars: Int
    var coinsSpent: Int
}

@MainActor
final class GameController: ObservableObject {
    @Published var campaign: Campaign = .new
    @Published var settings = PlayerSettings()
    @Published var isPlaying = false
    @Published var tool: BuildTool = .piece(.orchard)
    @Published var message = "A little road can go a long way."
    @Published var messageIsError = false
    @Published var sheet: GameSheet?
    @Published var inspected: Position?
    @Published var hovered: Position?
    @Published var isAnimating = false
    @Published var saveError: String?
    @Published var migrationNotice: String?
    @Published private(set) var hasUnreadableSave = false
    var reduceMotion = false
    let scene = BoardScene(size: CGSize(width: 390, height: 390))
    private let store: CampaignStore
    private let feedback = Feedback()
    private var animationTask: Task<Void, Never>?

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let testing = arguments.contains("--uitesting")
        store = CampaignStore(testing: testing)
        if testing && (arguments.contains("--reset-progress") || arguments.contains("--reset-journey")) {
            try? store.resetTestingData()
        }
        do {
            if let loaded = try store.load() {
                campaign = loaded.save.campaign
                settings = loaded.save.settings
                if loaded.importedSettings {
                    migrationNotice = "A fresh set of 12 puzzles. Your earlier island save is preserved."
                    do { try store.save(loaded.save) }
                    catch { saveError = "Could not save the new campaign: \(error.localizedDescription)" }
                }
            }
        } catch {
            saveError = "Could not open your progress. \(error.localizedDescription)"
            hasUnreadableSave = true
        }
        scene.onTap = { [weak self] point in self?.tap(Position(row: point.row, col: point.col)) }
        scene.onRoadStroke = { [weak self] points in
            self?.roadStroke(points.map { Position(row: $0.row, col: $0.col) })
        }
        scene.onHover = { [weak self] point in
            self?.hovered = point.map { Position(row: $0.row, col: $0.col) }
        }
    }

    var state: GameState { campaign.current }
    var level: LevelDefinition { state.level }
    var liveEvaluation: Evaluation { Rules.evaluate(state) }
    var selectedPiece: Piece? { if case let .piece(piece) = tool { return piece }; return nil }
    var totalStars: Int { campaign.totalStars }
    var canAdvance: Bool { state.canAdvance && state.levelIndex < Balance.levels.count - 1 && !isAnimating }
    var currentResult: LevelResult? {
        guard state.canAdvance else { return nil }
        return LevelResult(stars: level.stars(forSpent: state.spentCoins), coinsSpent: state.spentCoins)
    }
    var hasProgress: Bool { !campaign.records.isEmpty || !campaign.undoHistory.isEmpty || state.evaluation != nil }
    func isUnlocked(_ index: Int) -> Bool { !hasUnreadableSave && index <= campaign.highestUnlockedIndex }
    func bestStars(for index: Int) -> Int { campaign.record(for: index)?.stars ?? 0 }
    func bestCoins(for index: Int) -> Int? { campaign.record(for: index)?.spentCoins }

    func begin() { startLevel(0) }

    func startLevel(_ index: Int) {
        guard !hasUnreadableSave else { fail("Your progress file needs recovery before playing."); return }
        var next = campaign
        do {
            try next.startLevel(index)
            restore(next, message: Balance.levels[index].hint)
            isPlaying = true
        } catch { fail(error.localizedDescription) }
    }

    func resume() {
        guard !hasUnreadableSave else { return }
        cancelAnimation()
        isPlaying = true
        tool = campaign.undoHistory.isEmpty ? .piece(firstProducer) : .inspect
        message = campaign.undoHistory.isEmpty ? level.hint : "Your plan is just as you left it."
        messageIsError = false
        render()
        if currentResult != nil { sheet = .result }
    }

    private var firstProducer: Piece { level.availablePieces.first(where: { !$0.isInfrastructure }) ?? .road }

    func select(_ selection: BuildTool) {
        guard !isAnimating else { return }
        tool = selection
        messageIsError = false
        switch selection {
        case let .piece(piece):
            switch piece {
            case .field: message = "Beside water or on wetland. 3 food; +2 on wetland or within 2 steps of a connected reservoir."
            case .reservoir: message = "Beside water. Connect by road for +2 food to fields within 2 orthogonal steps."
            default: message = Balance.definition(for: piece).rule
            }
        case .inspect: message = "Tap a tile to see its output and road connection."
        case .remove: message = "Remove a piece for a full coin refund. Your best stars stay saved."
        case .clear: message = "Clear woodland for \(Balance.clearingCost) gold coins. No timber is gained."
        }
        render()
    }

    func tap(_ position: Position) {
        guard !isAnimating else { return }
        switch tool {
        case let .piece(piece): perform(.place(piece, position))
        case .remove: perform(.remove(position))
        case .clear: perform(.clearWoodland(position))
        case .inspect: inspect(position)
        }
    }

    func inspect(_ position: Position) {
        inspected = position
        sheet = .inspection
        render()
    }

    func perform(_ action: GameAction) {
        guard !isAnimating, !hasUnreadableSave else { return }
        var next = campaign
        do {
            try next.apply(action)
            scene.cancelTransientAnimations()
            campaign = next
            messageIsError = false
            switch action {
            case let .place(piece, position):
                if piece.isInfrastructure {
                    message = "\(piece.title) placed at \(position.label). \(state.spentCoins) gold coins spent."
                } else if let result = liveEvaluation.producers.first(where: { $0.position == position }) {
                    message = "\(piece.title) at \(position.label). \(result.reason)"
                }
            case .remove: message = "Piece removed. Its gold coins are refunded."
            case .clearWoodland: message = "Woodland cleared for \(Balance.clearingCost) gold coins."
            }
            if state.levelIndex == 0 && liveEvaluation.meetsOrder { message = "Connected! Tap Dispatch to deliver the order and earn your stars." }
            feedback.play("placement", settings: settings)
            persist()
            render()
            if case let .place(_, position) = action { scene.animatePlacement(at: position.visual) }
        } catch { fail(error.localizedDescription) }
    }

    func roadStroke(_ positions: [Position]) {
        guard !isAnimating, selectedPiece == .road, !hasUnreadableSave else { return }
        var next = campaign
        do {
            try next.applyRoadStroke(positions)
            campaign = next
            message = liveEvaluation.meetsOrder ? "Connected! Dispatch when you’re ready." : "Route laid. Undo removes this whole stroke."
            messageIsError = false
            feedback.play("placement", settings: settings)
            persist()
            render()
        } catch { fail(error.localizedDescription) }
    }

    func undo() {
        guard campaign.canUndo, !isAnimating else { return }
        campaign.undo()
        message = "Last change undone, including its coins and dispatch result."
        messageIsError = false
        persist()
        render()
    }

    func dispatch() {
        guard !isAnimating, !hasUnreadableSave else { return }
        let result = campaign.dispatch()
        persist()
        render()
        isAnimating = true
        scene.inputEnabled = false
        messageIsError = !result.meetsOrder
        message = result.meetsOrder ? "Order fulfilled. \(state.spentCoins) gold coins spent." : incompleteMessage(result)
        let deliveries = result.producers.filter { $0.worked && $0.resource != nil }.map { producer in
            let resource: DeliveryResource
            switch producer.resource! {
            case .stone: resource = .stone
            case .food: resource = .food
            case .timber: resource = .timber
            }
            return DeliveryVisual(route: producer.route.map(\.visual), resource: resource)
        }
        let duration = max(0.15, scene.animateDeliveries(deliveries))
        feedback.play("delivery", settings: settings)
        animationTask?.cancel()
        animationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, let self else { return }
            self.isAnimating = false
            self.scene.inputEnabled = true
            if self.currentResult != nil {
                self.feedback.play("era", settings: self.settings)
                self.sheet = .result
            }
        }
    }

    private func incompleteMessage(_ evaluation: Evaluation) -> String {
        let missing = Resource.allCases.filter { evaluation.totals[$0] < level.order[$0] }
            .map { "\(level.order[$0] - evaluation.totals[$0]) \($0.rawValue)" }.joined(separator: ", ")
        let idle = evaluation.producers.filter { !$0.worked }.count
        return "Still need \(missing)." + (idle > 0 ? " Every producer needs a road route; inspect idle sites." : " Add connected producers.")
    }

    func advance() {
        guard canAdvance else { return }
        var next = campaign
        do {
            try next.advance()
            restore(next, message: next.current.level.hint)
            isPlaying = true
        } catch { fail(error.localizedDescription) }
    }

    func restart() {
        var next = campaign
        next.restartLevel()
        restore(next, message: "Fresh island, full coin budget. Your best stars are safe.")
    }

    private func restore(_ next: Campaign, message: String) {
        cancelAnimation()
        campaign = next
        inspected = nil
        sheet = nil
        tool = .piece(firstProducer)
        self.message = message
        messageIsError = false
        persist()
        render()
    }

    private func cancelAnimation() {
        animationTask?.cancel()
        scene.cancelTransientAnimations()
        isAnimating = false
    }

    func goHome() {
        interrupted()
        sheet = nil
        isPlaying = false
    }

    func interrupted() {
        cancelAnimation()
        persist()
        render()
    }

    func persist() {
        guard !hasUnreadableSave else { return }
        do {
            try store.save(SavedCampaign(campaign: campaign, settings: settings))
            saveError = nil
        } catch { saveError = "Could not save this change: \(error.localizedDescription)" }
    }

    func recoverProgress() {
        do {
            try store.preserveUnreadableSave()
            campaign = .new
            hasUnreadableSave = false
            persist()
            message = "A new campaign is ready. The previous progress file was preserved separately."
        } catch { saveError = "Could not preserve the previous file: \(error.localizedDescription)" }
    }

    func fail(_ text: String) {
        message = text
        messageIsError = true
        feedback.invalid(settings: settings)
    }

    func render() {
        let current = state
        let evaluation = liveEvaluation
        let cells = Board.positions.map { position in
            let tile = current.board[position]
            let producer = evaluation.producers.first { $0.position == position }
            return BoardCellVisual(
                point: position.visual, terrain: tile.terrain.visual,
                building: position == current.board.depot ? .depot : tile.building?.visual,
                infrastructure: tile.infrastructure?.visual,
                isInherited: false,
                isConnected: producer?.worked,
                isSelected: inspected == position,
                placementAllowed: selectedPiece.map { Rules.placementError($0, at: position, in: current) == nil },
                futureChanged: false
            )
        }
        scene.drawsRoads = selectedPiece == .road
        scene.inputEnabled = !isAnimating
        scene.render(BoardSceneModel(cells: cells, isPreview: false, reduceMotion: reduceMotion))
    }
}
