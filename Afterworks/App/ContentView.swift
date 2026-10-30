import SwiftUI
import SpriteKit
import AfterworksCore

struct ContentView: View {
    @ObservedObject var game: GameController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmNew = false
    @State private var boardFrame = CGRect.zero
    @State private var dragPiece: Piece?
    @State private var dragPoint = CGPoint.zero

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            if game.isPlaying { playScreen } else { welcome }
            if let piece = dragPiece {
                VStack(spacing: 2) {
                    PieceGlyph(piece: piece.visual).frame(width: 44, height: 44)
                    Text(game.hovered?.label ?? "Place on island").font(.system(size: 11, weight: .bold))
                }
                .padding(8).background(Palette.paper, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: Palette.ink.opacity(0.2), radius: 8, y: 4)
                .position(x: dragPoint.x, y: dragPoint.y - 76)
                .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: "screen")
        .foregroundStyle(Palette.ink)
        .sheet(item: $game.sheet) { sheet in
            GameSheets(game: game, kind: sheet)
                .presentationBackground(Palette.paper)
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Start a new journey?", isPresented: $confirmNew, titleVisibility: .visible) {
            Button("Replace journey", role: .destructive) { game.begin() }
            Button("Keep current journey", role: .cancel) { }
        } message: { Text("Your current island and its checkpoints will be replaced.") }
        .onAppear { game.reduceMotion = reduceMotion; game.render() }
        .onChange(of: reduceMotion) { _, value in game.reduceMotion = value; game.render() }
    }

    private var welcome: some View {
        GeometryReader { geo in
          ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: 12)
                Text("A SMALL GAME ABOUT WHAT REMAINS")
                    .font(.system(size: 9, weight: .bold)).tracking(2.1).foregroundStyle(Palette.secondary)
                Text("Afterworks").font(.custom("Georgia", size: 49)).padding(.top, 12)
                Text("Build for today. Shape tomorrow.")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.secondary).padding(.top, 9)
                SpriteView(scene: welcomeScene, options: [.allowsTransparency])
                    .frame(width: min(geo.size.width, 410), height: min(geo.size.width, geo.size.height * (geo.size.height < 720 ? 0.30 : 0.43)))
                    .allowsHitTesting(false).accessibilityHidden(true)
                    .padding(.top, 6)
                Text("The quarry becomes a lake.\nThe orchard becomes a wood.\nWhat will your island become?")
                    .font(.custom("Georgia", size: 17)).lineSpacing(5).multilineTextAlignment(.center)
                    .foregroundStyle(Palette.secondary).padding(.bottom, 22)
                VStack(spacing: 10) {
                    if game.journey != nil {
                        Button(game.journey?.finished == true ? "View your island" : "Continue · Era \(game.state.eraIndex + 1)") { game.resume() }
                            .buttonStyle(PaperButtonStyle(filled: true)).accessibilityIdentifier("continue")
                    }
                    Button(game.journey == nil ? "Begin your journey" : "New journey") {
                        if game.hasJourney { confirmNew = true } else { game.begin() }
                    }
                    .buttonStyle(PaperButtonStyle(filled: game.journey == nil)).accessibilityIdentifier("new-journey")
                }
                .frame(maxWidth: 330)
                if let error = game.saveError {
                    Text(error).font(.footnote).foregroundStyle(Palette.clay).padding(.top, 10)
                }
                Spacer(minLength: 14)
                Text("THREE ERAS  ·  ONE ISLAND  ·  EVERY CHOICE REMAINS")
                    .font(.system(size: 8, weight: .semibold)).tracking(1.1).foregroundStyle(Palette.secondary)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 22).frame(maxWidth: .infinity, minHeight: geo.size.height)
          }
        }
    }

    private var welcomeScene: BoardScene {
        let scene = BoardScene(size: CGSize(width: 390, height: 390))
        var board = Board.initial
        for p in [Position(row: 5, col: 3), Position(row: 4, col: 3), Position(row: 3, col: 3), Position(row: 4, col: 2)] {
            board[p].infrastructure = .road
        }
        board[Position(row: 4, col: 1)].building = .quarry
        board[Position(row: 3, col: 4)].building = .orchard
        board[Position(row: 2, col: 2)].terrain = .woodland
        board[Position(row: 2, col: 4)].terrain = .water
        scene.render(BoardSceneModel(cells: Board.positions.map { p in
            BoardCellVisual(point: p.visual, terrain: board[p].terrain.visual,
                            building: p == board.depot ? .depot : board[p].building?.visual,
                            infrastructure: board[p].infrastructure?.visual)
        }, isPreview: false, reduceMotion: reduceMotion))
        scene.inputEnabled = false
        return scene
    }

    private var playScreen: some View {
        GeometryReader { geo in
            let boardSide = min(geo.size.width - 8, max(250, geo.size.height - 322))
            VStack(spacing: 0) {
                masthead
                objective
                Spacer(minLength: 0)
                ZStack {
                    SpriteView(scene: game.scene, options: [.allowsTransparency])
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Island, seven rows by seven columns")
                        .accessibilityHint("Use the tile list for accessible building and inspection.")
                        .accessibilityIdentifier("island-board")
                    if let title = game.transitionTitle {
                        VStack(spacing: 8) {
                            Image(systemName: "sun.max").font(.system(size: 25, weight: .light))
                            Text(title).font(.custom("Georgia", size: 24))
                        }
                        .padding(22).background(Palette.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 22))
                        .allowsHitTesting(false)
                    }
                }
                .frame(width: boardSide, height: boardSide)
                .background(GeometryReader { boardGeo in
                    Color.clear.onAppear { boardFrame = boardGeo.frame(in: .named("screen")) }
                        .onChange(of: boardGeo.frame(in: .named("screen"))) { _, rect in boardFrame = rect }
                })
                Spacer(minLength: 0)
                utilityBar
                contextNote
                buildingTray
                dispatchButton
                    .padding(.horizontal, 18).padding(.top, 5).padding(.bottom, 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var masthead: some View {
        HStack(spacing: 8) {
            Text(game.preview ? "FUTURE PREVIEW" : "AFTERWORKS").font(.system(size: 11, weight: .bold)).tracking(2.3)
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle().fill(index <= game.state.eraIndex ? Palette.ink : Palette.faint).frame(width: 5, height: 5)
                }
                Text(game.preview ? "FROM ERA \(game.state.eraIndex + 1)" : "ERA \(game.state.eraIndex + 1) / 3").font(.system(size: 9, weight: .bold)).tracking(0.8).padding(.leading, 4)
            }.accessibilityElement(children: .ignore).accessibilityLabel("Era \(game.state.eraIndex + 1) of 3")
            Button { game.sheet = .menu } label: { Image(systemName: "line.3.horizontal").font(.system(size: 18)).frame(width: 40, height: 36) }
                .accessibilityLabel("Journey menu").accessibilityIdentifier("menu")
        }
        .padding(.leading, 22).padding(.trailing, 9).frame(height: 36)
    }

    private var objective: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(game.journey?.finished == true ? "An island, remembered" : game.scenario.title).font(.custom("Georgia", size: 25))
                    .lineLimit(1).minimumScaleFactor(0.8).accessibilityIdentifier("era-title")
                Spacer(minLength: 5)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(game.state.budget)").font(.system(size: 24, weight: .medium, design: .rounded)).monospacedDigit()
                        .accessibilityIdentifier("budget-number")
                    Text("BUILD").font(.system(size: 8, weight: .bold)).tracking(0.7)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(game.state.budget) construction remaining")
            }
            HStack(spacing: 13) {
                Text(game.journey?.finished == true ? "SENT" : game.state.evaluation == nil ? "PLAN" : "SENT")
                    .font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(Palette.secondary)
                ForEach(Resource.allCases.filter { game.scenario.order[$0] > 0 }) { resource in
                    HStack(spacing: 4) {
                        ResourceMark(resource: resource, size: 11)
                        Text("\(shownTotals[resource]) / \(game.scenario.order[resource])")
                            .font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(resource.title): \(shownTotals[resource]) of \(game.scenario.order[resource]) required")
                }
                Spacer(minLength: 0)
                Button { game.sheet = .guide } label: {
                    Image(systemName: "questionmark.circle").font(.system(size: 15)).frame(width: 30, height: 25)
                }.accessibilityLabel("Rules and next order").accessibilityIdentifier("guide")
            }
            Text(game.state.eraIndex < 2 ? "NEXT  \(Balance.scenarios[game.state.eraIndex + 1].order.summary)  ·  depot stays" : "FINAL ERA  ·  Make something worth leaving behind")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 22).frame(height: 77)
    }

    private var utilityBar: some View {
        HStack(spacing: 2) {
            Button { game.togglePreview() } label: {
                HStack(spacing: 5) {
                    Image(systemName: game.preview ? "arrow.uturn.backward" : "sparkle").font(.system(size: 14))
                    Text(game.preview ? "Back to planning" : (game.state.eraIndex == 2 ? "Preview legacy" : "Preview next era"))
                        .font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                }.frame(maxWidth: .infinity, minHeight: 40)
                    .background(game.preview ? Palette.water.opacity(0.2) : Palette.faint.opacity(0.5), in: Capsule())
            }.accessibilityIdentifier("preview").disabled(game.isAnimating || game.journey?.finished == true)
            toolButton("arrow.uturn.backward", label: "Undo", id: "undo", selected: false) { game.undo() }
                .disabled(game.journey?.canUndo != true || game.preview || game.isAnimating)
            toolButton("cursorarrow", label: "Inspect tile", id: "inspect", selected: game.tool == .inspect) { game.select(.inspect) }
            toolButton("eraser", label: "Remove piece", id: "remove", selected: game.tool == .remove) { game.select(.remove) }
                .disabled(game.isAnimating || game.journey?.finished == true)
            toolButton("list.bullet", label: "Accessible tile list", id: "tile-list", selected: false) { game.sheet = .tiles }
        }
        .padding(.horizontal, 18).frame(height: 44)
    }

    private func toolButton(_ icon: String, label: String, id: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .medium))
                .frame(width: 40, height: 40)
                .background(selected ? Palette.faint : Color.clear, in: Circle())
        }.accessibilityLabel(label).accessibilityIdentifier(id)
    }

    private var contextNote: some View {
        HStack(alignment: .center, spacing: 6) {
            if game.messageIsError { Image(systemName: "exclamationmark.circle.fill").font(.system(size: 11)) }
            Text(game.saveError ?? game.message)
                .font(.system(size: 11, weight: .medium)).lineLimit(2).minimumScaleFactor(0.88)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("feedback")
        }
        .foregroundStyle(game.messageIsError || game.saveError != nil ? Palette.clay : Palette.secondary)
        .padding(.horizontal, 24).frame(height: 34)
        .accessibilityElement(children: .combine)
    }

    private var buildingTray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(game.scenario.availablePieces) { piece in
                    let definition = Balance.definition(for: piece)
                    let selected = game.selectedPiece == piece && !game.preview
                    Button { game.select(.piece(piece)) } label: {
                        VStack(spacing: 1) {
                            HStack(spacing: 0) {
                                PieceGlyph(piece: piece.visual).frame(width: 36, height: 34)
                                Text("\(definition.cost)").font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            Text(piece.shortTitle).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                            Text(piece.isInfrastructure ? "\(definition.cost) build" : "\(max(0, definition.limit - game.state.count(of: piece))) left")
                                .font(.system(size: 8, weight: .medium)).foregroundStyle(Palette.secondary)
                        }
                        .frame(width: 69, height: 65)
                        .background(selected ? Palette.faint : Palette.paper.opacity(0.7), in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(selected ? Palette.ink.opacity(0.7) : Palette.faint, lineWidth: selected ? 1.5 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(piece.title), costs \(definition.cost) construction, \(definition.output > 0 ? "produces \(definition.output) \(definition.resource?.rawValue ?? "")" : definition.rule)")
                    .accessibilityHint("Select then tap a tile, or drag onto the island. \(definition.legacy)")
                    .accessibilityIdentifier("piece-\(piece.rawValue)")
                    .simultaneousGesture(DragGesture(minimumDistance: 14, coordinateSpace: .named("screen"))
                        .onChanged { value in
                            guard !game.isAnimating, !game.preview else { return }
                            if dragPiece == nil {
                                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                                dragPiece = piece
                                game.select(.piece(piece))
                            }
                            guard dragPiece == piece else { return }
                            dragPoint = value.location
                            let local = CGPoint(x: value.location.x - boardFrame.minX, y: value.location.y - boardFrame.minY)
                            game.hovered = game.scene.gridPoint(atViewPoint: local, in: boardFrame.size).map { Position(row: $0.row, col: $0.col) }
                            game.scene.showHover(at: game.hovered?.visual, allowed: game.hovered.map { Rules.placementError(piece, at: $0, in: game.state) == nil } ?? false)
                        }
                        .onEnded { value in
                            guard dragPiece == piece else { return }
                            let local = CGPoint(x: value.location.x - boardFrame.minX, y: value.location.y - boardFrame.minY)
                            if let point = game.scene.gridPoint(atViewPoint: local, in: boardFrame.size) {
                                game.tap(Position(row: point.row, col: point.col))
                            }
                            dragPiece = nil
                            game.hovered = nil
                            game.scene.showHover(at: nil)
                        })
                }
                Button { game.select(.clear) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "leaf.slash").font(.system(size: 23, weight: .light)).frame(height: 30)
                        Text("Clear woods").font(.system(size: 9, weight: .semibold))
                        Text("\(Balance.clearingCost) build").font(.system(size: 8, weight: .medium))
                    }.frame(width: 75, height: 65)
                        .background(game.tool == .clear ? Palette.faint : .clear, in: RoundedRectangle(cornerRadius: 13))
                }.buttonStyle(.plain).accessibilityIdentifier("clear-woods")
                    .accessibilityLabel("Clear woodland, costs \(Balance.clearingCost), produces no timber")
            }.padding(.horizontal, 18)
        }
        .frame(height: 71).disabled(game.isAnimating || game.journey?.finished == true)
        .opacity(game.preview ? 0.45 : 1)
    }

    private var dispatchButton: some View {
        Button {
            if game.journey?.finished == true { game.sheet = .result }
            else if game.canAdvance { game.advance() }
            else { game.dispatch() }
        } label: {
            HStack(spacing: 8) {
                Text(game.journey?.finished == true ? "Your island’s story" : game.isAnimating ? "Watching the island…" : game.canAdvance ? (game.state.eraIndex == 2 ? "Complete the journey" : "Advance era") : "Dispatch")
                if !game.isAnimating { Image(systemName: game.canAdvance ? "arrow.right" : "shippingbox").font(.system(size: 14)) }
            }
        }
        .buttonStyle(PaperButtonStyle(filled: true))
        .disabled(game.isAnimating || game.preview)
        .opacity(game.preview ? 0.45 : 1)
        .accessibilityIdentifier(game.canAdvance ? "advance" : "dispatch")
    }

    private var shownTotals: Resources {
        game.journey?.finished == true ? game.journey?.eraResults.last?.totals ?? Resources() : game.liveEvaluation.totals
    }
}
