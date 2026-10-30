import SwiftUI
import SpriteKit
import AfterworksCore

enum BuildTool: Equatable {
    case piece(Piece), inspect, remove, clear
}

enum GameSheet: String, Identifiable {
    case menu, guide, tiles, inspection, result
    var id: String { rawValue }
}

@MainActor
final class GameController: ObservableObject {
    @Published var journey: Journey?
    @Published var settings = PlayerSettings()
    @Published var isPlaying = false
    @Published var preview = false
    @Published var tool: BuildTool = .piece(.quarry)
    @Published var message = "Choose a quarry, then tap a pale stone tile."
    @Published var messageIsError = false
    @Published var sheet: GameSheet?
    @Published var inspected: Position?
    @Published var hovered: Position?
    @Published var isAnimating = false
    @Published var saveError: String?
    @Published var transitionTitle: String?
    var reduceMotion = false
    let scene = BoardScene(size: CGSize(width: 390, height: 390))
    private let store: JourneyStore
    private let feedback = Feedback()
    private var animationTask: Task<Void, Never>?
    private(set) var hasUnreadableSave = false

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let testing = arguments.contains("--uitesting")
        store = JourneyStore(testing: testing)
        if testing && arguments.contains("--reset-journey") { try? store.resetTestingData() }
        do {
            if let saved = try store.load() {
                journey = saved.journey
                settings = saved.settings
            }
        } catch {
            saveError = error.localizedDescription
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

    var state: GameState { journey?.current ?? Journey.new.current }
    var scenario: Scenario { Balance.scenarios[state.eraIndex] }
    var liveEvaluation: Evaluation { Rules.evaluate(state) }
    var selectedPiece: Piece? { if case let .piece(piece) = tool { return piece }; return nil }
    var hasJourney: Bool { journey != nil || hasUnreadableSave }
    var canAdvance: Bool { state.canAdvance && !isAnimating && !preview }
    var displayedBoard: Board { preview ? Rules.transformedBoard(state) : state.board }

    func begin() {
        animationTask?.cancel()
        scene.cancelTransientAnimations()
        journey = .new
        hasUnreadableSave = false
        isPlaying = true
        preview = false
        isAnimating = false
        transitionTitle = nil
        tool = .piece(.quarry)
        message = "Choose a quarry, then tap a pale stone tile."
        messageIsError = false
        sheet = nil
        persist()
        render()
    }

    func resume() {
        guard journey != nil else { return }
        isPlaying = true
        preview = false
        tool = .inspect
        message = journey?.finished == true ? "Three eras. One island shaped by you." : "Your island is just as you left it."
        render()
        if journey?.finished == true { sheet = .result }
    }

    func select(_ selection: BuildTool) {
        guard !isAnimating else { return }
        if preview && selection != .inspect { togglePreview() }
        tool = selection
        messageIsError = false
        switch selection {
        case let .piece(piece):
            switch piece {
            case .field: message = "Beside lake or on wetland. 3 food; +2 on wetland or within 2 steps of a connected reservoir."
            case .reservoir: message = "Beside a lake. Connect for +2 food to fields within 2 orthogonal steps."
            default: message = Balance.definition(for: piece).rule
            }
        case .inspect: message = preview ? "Tap a tile to compare its present and future." : "Tap a tile to see its output, route, and future."
        case .remove: message = "New pieces refund their cost. Removing an old route costs 1."
        case .clear: message = "Clear woodland for \(Balance.clearingCost) construction. No timber is gained."
        }
        render()
    }

    func tap(_ position: Position) {
        guard !isAnimating, journey?.finished != true else {
            if journey?.finished == true { inspect(position) }
            return
        }
        if preview || tool == .inspect { inspect(position); return }
        switch tool {
        case let .piece(piece): perform(.place(piece, position))
        case .remove: perform(.remove(position))
        case .clear: perform(.clearWoodland(position))
        case .inspect: break
        }
    }

    func inspect(_ position: Position) {
        inspected = position
        sheet = .inspection
        render()
    }

    func perform(_ action: GameAction) {
        guard var next = journey, !preview, !isAnimating, !next.finished else { return }
        do {
            try next.apply(action)
            scene.cancelTransientAnimations()
            journey = next
            messageIsError = false
            switch action {
            case let .place(piece, position):
                message = "\(piece.title) placed at \(position.label). \(Balance.definition(for: piece).legacy)"
                if state.eraIndex == 0 {
                    if piece == .quarry && state.tutorialProgress == 0 {
                        journey?.current.tutorialProgress = 1
                        message = "Connect this quarry with roads, then preview the lake it will leave."
                    } else if piece == .orchard && state.tutorialProgress >= 2 {
                        journey?.current.tutorialProgress = 3
                        message = "Connect your producers to the depot with roads. Then dispatch."
                    }
                }
            case .remove: message = "Piece removed. New pieces refund their cost; old routes cost 1 to remove."
            case .clearWoodland: message = "Woodland cleared. The ground is ready to use."
            }
            feedback.play("placement", settings: settings)
            guideFirstLegacy()
            persist()
            render()
            if case let .place(_, position) = action { scene.animatePlacement(at: position.visual) }
        } catch { fail(error.localizedDescription) }
    }

    func roadStroke(_ positions: [Position]) {
        guard var next = journey, !preview, !isAnimating, selectedPiece == .road else { return }
        do {
            try next.applyRoadStroke(positions)
            journey = next
            message = "Route laid. Undo removes this whole stroke."
            messageIsError = false
            guideFirstLegacy()
            feedback.play("placement", settings: settings)
            persist()
            render()
        } catch { fail(error.localizedDescription) }
    }

    func undo() {
        guard var next = journey, next.canUndo, !preview, !isAnimating else { return }
        next.undo()
        journey = next
        message = "Last change undone, including its budget and dispatch result."
        messageIsError = false
        persist()
        render()
    }

    func togglePreview() {
        guard !isAnimating, journey?.finished != true else { return }
        preview.toggle()
        messageIsError = false
        if preview {
            let hasLegacy = liveEvaluation.producers.contains { $0.worked }
            if hasLegacy && state.eraIndex == 0 && state.tutorialProgress < 2 { journey?.current.tutorialProgress = 2 }
            message = hasLegacy ? "Tomorrow, at these exact coordinates. Tap a tile to inspect." : "No working sites yet. Connect them to the depot to leave a legacy."
        } else {
            message = "Back to your unchanged plan. Every placement shapes tomorrow."
        }
        persist()
        render()
    }

    func dispatch() {
        guard var next = journey, !preview, !isAnimating, !next.finished else { return }
        let result = next.dispatch()
        if next.current.eraIndex == 0 { next.current.tutorialProgress = 4 }
        journey = next
        persist()
        render()
        isAnimating = true
        scene.inputEnabled = false
        messageIsError = !result.meetsOrder
        message = result.meetsOrder ? "Order fulfilled. Your island is ready for its next chapter." : incompleteMessage(result)
        let deliveries = result.producers.filter { $0.worked && $0.resource != nil }.map { producer in
            let resource: DeliveryResource
            switch producer.resource! {
            case .stone: resource = .stone
            case .food: resource = .food
            case .timber: resource = .timber
            }
            return DeliveryVisual(route: producer.route.map(\.visual), resource: resource)
        }
        let deliveryDuration = max(0.15, scene.animateDeliveries(deliveries))
        feedback.play("delivery", settings: settings)
        animationTask?.cancel()
        animationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(deliveryDuration))
            guard !Task.isCancelled, let self else { return }
            self.isAnimating = false
            self.scene.inputEnabled = true
        }
    }

    private func incompleteMessage(_ evaluation: Evaluation) -> String {
        let missing = [
            ("stone", scenario.order.stone - evaluation.totals.stone),
            ("food", scenario.order.food - evaluation.totals.food),
            ("timber", scenario.order.timber - evaluation.totals.timber)
        ].filter { $0.1 > 0 }.map { "\($0.1) \($0.0)" }.joined(separator: ", ")
        let idle = evaluation.producers.filter { !$0.worked }.count
        return "Still need \(missing)." + (idle > 0 ? " Inspect \(idle) idle site\(idle == 1 ? "" : "s") for help." : " Add more connected producers.")
    }

    func advance() {
        guard var next = journey, canAdvance, !next.finished else { return }
        do {
            try next.advance()
            journey = next
            persist()
            isAnimating = true
            preview = false
            inspected = nil
            tool = .inspect
            transitionTitle = next.finished ? "Your island, through time." : "The years take root."
            feedback.play("era", settings: settings)
            scene.inputEnabled = false
            scene.animateEraTransition { [weak self] in self?.render() }
            animationTask?.cancel()
            animationTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(self?.reduceMotion == true ? 0.2 : 1.7))
                guard !Task.isCancelled, let self else { return }
                self.isAnimating = false
                self.transitionTitle = nil
                self.messageIsError = false
                self.message = next.finished ? "Three eras. One island shaped by you." : "Look closely. This landscape is the plan you left behind."
                self.render()
                if next.finished { self.sheet = .result }
            }
        } catch { fail(error.localizedDescription) }
    }

    func restart() {
        guard var next = journey else { return }
        next.restartEra()
        restore(next, message: "This era has a fresh budget. Your inherited landscape is preserved.")
    }

    func rewind() {
        guard var next = journey else { return }
        do {
            try next.rewind()
            restore(next, message: "Back at the previous era’s beginning. Try a different legacy.")
        } catch { fail(error.localizedDescription) }
    }

    private func restore(_ next: Journey, message: String) {
        animationTask?.cancel()
        scene.cancelTransientAnimations()
        journey = next
        preview = false
        isAnimating = false
        transitionTitle = nil
        inspected = nil
        sheet = nil
        tool = .inspect
        self.message = message
        messageIsError = false
        persist()
        render()
    }

    func goHome() {
        interrupted()
        sheet = nil
        isPlaying = false
    }

    func interrupted() {
        animationTask?.cancel()
        scene.cancelTransientAnimations()
        isAnimating = false
        transitionTitle = nil
        persist()
        render()
    }

    func persist() {
        guard !hasUnreadableSave else { return }
        do {
            try store.save(SavedJourney(journey: journey, settings: settings))
            saveError = nil
        } catch { saveError = "Could not save this change: \(error.localizedDescription)" }
    }

    func fail(_ text: String) {
        message = text
        messageIsError = true
        feedback.invalid(settings: settings)
    }

    private func guideFirstLegacy() {
        if state.eraIndex == 0, state.tutorialProgress < 2,
           liveEvaluation.producers.contains(where: { $0.piece == .quarry && $0.worked }) {
            message = "Your quarry now leaves a lake. Preview tomorrow before planting orchards."
        }
    }

    func render() {
        let current = state
        let board = displayedBoard
        let evaluation = Rules.evaluate(current)
        let cells = (0..<7).flatMap { row in (0..<7).map { col in
            let position = Position(row: row, col: col)
            let tile = board[position]
            let isDepot = position == board.depot
            let producer = evaluation.producers.first { $0.position == position }
            let allowed: Bool? = !preview && selectedPiece != nil && journey?.finished != true
                ? Rules.placementError(selectedPiece!, at: position, in: current) == nil : nil
            return BoardCellVisual(
                point: position.visual, terrain: tile.terrain.visual,
                building: isDepot ? .depot : tile.building?.visual,
                infrastructure: tile.infrastructure?.visual,
                isInherited: tile.inheritedInfrastructure,
                isConnected: producer?.worked ?? true,
                isSelected: inspected == position,
                placementAllowed: allowed,
                futureChanged: preview && tile != current.board[position]
            )
        } }
        scene.drawsRoads = selectedPiece == .road && !preview
        scene.inputEnabled = !isAnimating
        scene.render(BoardSceneModel(cells: cells, isPreview: preview, reduceMotion: reduceMotion))
    }
}
