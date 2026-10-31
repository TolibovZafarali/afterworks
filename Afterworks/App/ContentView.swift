import SwiftUI
import SpriteKit
import AfterworksCore

struct ContentView: View {
    @ObservedObject var game: GameController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var boardFrame = CGRect.zero
    @State private var dragPiece: Piece?
    @State private var dragPoint = CGPoint.zero

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            if game.isPlaying { playScreen } else { LevelMapView(game: game) }
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
        .onAppear { game.reduceMotion = reduceMotion; game.render() }
        .onChange(of: reduceMotion) { _, value in game.reduceMotion = value; game.render() }
    }

    private var playScreen: some View {
        GeometryReader { geo in
            let boardSide = min(geo.size.width - 8, max(240, geo.size.height - 318))
            VStack(spacing: 0) {
                masthead
                objective
                Spacer(minLength: 0)
                SpriteView(scene: game.scene, options: [.allowsTransparency])
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Island, seven rows by seven columns")
                    .accessibilityHint("Use the tile list for accessible building and inspection.")
                    .accessibilityIdentifier("island-board")
                    .frame(width: boardSide, height: boardSide)
                    .background(GeometryReader { boardGeo in
                        Color.clear.onAppear { boardFrame = boardGeo.frame(in: .named("screen")) }
                            .onChange(of: boardGeo.frame(in: .named("screen"))) { _, rect in boardFrame = rect }
                    })
                Spacer(minLength: 0)
                utilityBar
                contextNote
                buildingTray
                dispatchButton.padding(.horizontal, 18).padding(.top, 5).padding(.bottom, 5)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var masthead: some View {
        HStack(spacing: 8) {
            Button { game.goHome() } label: {
                HStack(spacing: 7) {
                    Image(systemName: "square.grid.2x2").font(.system(size: 13, weight: .medium))
                    Text("AFTERWORKS").font(.system(size: 10, weight: .bold)).tracking(1.8)
                }.frame(minHeight: 34)
            }.accessibilityLabel("All levels").accessibilityIdentifier("levels-header")
            Spacer()
            Text("LEVEL \(game.state.levelIndex + 1) / \(Balance.levels.count)")
                .font(.system(size: 9, weight: .bold)).tracking(0.7)
                .accessibilityLabel("Level \(game.state.levelIndex + 1) of \(Balance.levels.count)")
                .accessibilityIdentifier("level-number")
            Button { game.sheet = .menu } label: {
                Image(systemName: "line.3.horizontal").font(.system(size: 18)).frame(width: 40, height: 34)
            }.accessibilityLabel("Level menu").accessibilityIdentifier("menu")
        }.padding(.leading, 22).padding(.trailing, 9).frame(height: 34)
    }

    private var objective: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(game.level.title).font(.custom("Georgia", fixedSize: 25))
                    .lineLimit(1).minimumScaleFactor(0.75).accessibilityIdentifier("level-title")
                Spacer(minLength: 5)
                HStack(spacing: 5) {
                    CoinGlyph(size: 21)
                    Text("\(game.state.budget)").font(.system(size: 24, weight: .medium, design: .rounded)).monospacedDigit()
                    Text("LEFT").font(.system(size: 8, weight: .bold)).tracking(0.7)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(game.state.budget) gold coins remaining")
                .accessibilityIdentifier("coins-number")
            }
            HStack(spacing: 13) {
                Text(game.state.evaluation == nil ? "ORDER" : "SENT")
                    .font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(Palette.secondary)
                ForEach(Resource.allCases.filter { game.level.order[$0] > 0 }) { resource in
                    HStack(spacing: 4) {
                        ResourceMark(resource: resource, size: 11)
                        Text("\(game.liveEvaluation.totals[resource]) / \(game.level.order[resource])")
                            .font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(resource.title): \(game.liveEvaluation.totals[resource]) of \(game.level.order[resource]) required")
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 5) {
                StarRating(stars: 3, size: 9)
                Text("\(game.level.minimumCoins) coins").font(.system(size: 10, weight: .semibold))
                Spacer()
                Text("Spent \(game.state.spentCoins)").font(.system(size: 10, weight: .medium)).monospacedDigit()
                    .accessibilityLabel("\(game.state.spentCoins) coins spent").accessibilityIdentifier("spent-coins")
            }
            .foregroundStyle(Palette.secondary)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Three stars at \(game.level.minimumCoins) coins")
            .accessibilityIdentifier("star-target")
        }.padding(.horizontal, 22).frame(height: 76)
    }

    private var utilityBar: some View {
        HStack(spacing: 2) {
            Button { game.sheet = .guide } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb").font(.system(size: 14))
                    Text("Goal & hints").font(.system(size: 12, weight: .semibold))
                }.frame(maxWidth: .infinity, minHeight: 40)
                    .background(Palette.faint.opacity(0.5), in: Capsule())
            }.accessibilityIdentifier("guide")
            toolButton("arrow.uturn.backward", label: "Undo", id: "undo", selected: false) { game.undo() }
                .disabled(!game.campaign.canUndo || game.isAnimating)
            toolButton("cursorarrow", label: "Inspect tile", id: "inspect", selected: game.tool == .inspect) { game.select(.inspect) }
            toolButton("eraser", label: "Remove piece", id: "remove", selected: game.tool == .remove) { game.select(.remove) }
            toolButton("list.bullet", label: "Accessible tile list", id: "tile-list", selected: false) { game.sheet = .tiles }
        }.padding(.horizontal, 18).frame(height: 44)
    }

    private func toolButton(_ icon: String, label: String, id: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .medium)).frame(width: 40, height: 40)
                .background(selected ? Palette.faint : Color.clear, in: Circle())
        }.accessibilityLabel(label).accessibilityIdentifier(id).disabled(game.isAnimating)
    }

    private var contextNote: some View {
        HStack(spacing: 6) {
            if game.messageIsError { Image(systemName: "exclamationmark.circle.fill").font(.system(size: 11)) }
            Text(game.saveError ?? game.message).font(.system(size: 11, weight: .medium))
                .lineLimit(2).minimumScaleFactor(0.85).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("feedback")
        }
        .foregroundStyle(game.messageIsError || game.saveError != nil ? Palette.clay : Palette.secondary)
        .padding(.horizontal, 24).frame(height: 34).accessibilityElement(children: .combine)
    }

    private var buildingTray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(game.level.availablePieces) { piece in
                    let definition = Balance.definition(for: piece)
                    let selected = game.selectedPiece == piece
                    let remaining = max(0, game.level.limit(for: piece) - game.state.count(of: piece))
                    Button { game.select(.piece(piece)) } label: {
                        VStack(spacing: 1) {
                            HStack(spacing: 2) {
                                PieceGlyph(piece: piece.visual).frame(width: 33, height: 31)
                                CoinGlyph(size: 10)
                                Text("\(definition.cost)").font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            Text(piece.shortTitle).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                            Text("\(remaining) left · \(piece.isInfrastructure ? "connects" : definition.output > 0 ? "+\(definition.output)" : "irrigates")")
                                .font(.system(size: 8, weight: .medium)).foregroundStyle(Palette.secondary).lineLimit(1)
                        }.frame(width: 78, height: 64)
                            .background(selected ? Palette.faint : Palette.paper.opacity(0.7), in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(selected ? Palette.ink.opacity(0.7) : Palette.faint, lineWidth: selected ? 1.5 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(piece.title), \(remaining) available, costs \(definition.cost) gold coins, \(definition.output > 0 ? "produces \(definition.output) \(definition.resource?.rawValue ?? "")" : definition.rule)")
                    .accessibilityHint("Select then tap a tile, or drag onto the island.")
                    .accessibilityIdentifier("piece-\(piece.rawValue)")
                    .simultaneousGesture(DragGesture(minimumDistance: 14, coordinateSpace: .named("screen"))
                        .onChanged { value in
                            guard !game.isAnimating else { return }
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
                if game.state.board.tiles.contains(where: { $0.terrain == .woodland }) {
                    Button { game.select(.clear) } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "leaf").font(.system(size: 23, weight: .light)).frame(height: 28)
                            Text("Clear woods").font(.system(size: 9, weight: .semibold))
                            HStack(spacing: 3) { CoinGlyph(size: 9); Text("\(Balance.clearingCost)").font(.system(size: 9, weight: .medium)) }
                        }.frame(width: 75, height: 64)
                            .background(game.tool == .clear ? Palette.faint : .clear, in: RoundedRectangle(cornerRadius: 13))
                    }.buttonStyle(.plain).accessibilityIdentifier("clear-woods")
                        .accessibilityLabel("Clear woodland, costs \(Balance.clearingCost) gold coins, produces no timber")
                }
            }.padding(.horizontal, 18)
        }.frame(height: 70).disabled(game.isAnimating)
            .accessibilityIdentifier("building-tray-scroll")
    }

    private var dispatchButton: some View {
        Button {
            if game.currentResult != nil { game.sheet = .result } else { game.dispatch() }
        } label: {
            HStack(spacing: 8) {
                Text(game.isAnimating ? "Goods on their way…" : game.currentResult != nil ? "View your stars" : "Dispatch")
                if !game.isAnimating { Image(systemName: game.currentResult != nil ? "star" : "shippingbox").font(.system(size: 14)) }
            }
        }.buttonStyle(PaperButtonStyle(filled: true)).disabled(game.isAnimating).accessibilityIdentifier("dispatch")
    }
}

struct LevelMapView: View {
    @ObservedObject var game: GameController
    var inSheet = false
    @State private var pendingLevel: Int?
    @State private var confirmSwitch = false
    @State private var confirmRecovery = false
    @State private var selectedChapter: Int?

    private let levelsPerChapter = 10
    private var maximumStars: Int { Balance.levels.count * 3 }
    private var chapterCount: Int { (Balance.levels.count + levelsPerChapter - 1) / levelsPerChapter }
    private var chapterIndex: Int { selectedChapter ?? game.state.levelIndex / levelsPerChapter }
    private var chapterLevels: [LevelDefinition] {
        Array(Balance.levels.dropFirst(chapterIndex * levelsPerChapter).prefix(levelsPerChapter))
    }
    private var chapterStars: Int { chapterLevels.reduce(0) { $0 + game.bestStars(for: $1.index) } }
    private var introduction: String {
        if game.totalStars == maximumStars {
            return "All \(Balance.levels.count) islands. All \(maximumStars) stars. Revisit a favorite and enjoy another clever connection."
        }
        if game.campaign.isComplete {
            return "All \(Balance.levels.count) islands delivered. Find a thriftier route and collect every star."
        }
        return "\(Balance.levels.count) small islands. Complete each order with fewer gold coins. Every island starts fresh."
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 19) {
                if !inSheet {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SMALL ISLANDS. CLEVER CONNECTIONS.").font(.system(size: 8, weight: .bold)).tracking(1.5).foregroundStyle(Palette.secondary)
                            Text("Afterworks").font(.custom("Georgia", fixedSize: 42)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        Spacer()
                        VStack(spacing: 5) {
                            Image(systemName: "star.fill").font(.system(size: 24)).foregroundStyle(Palette.gold)
                            Text("\(game.totalStars) / \(maximumStars)").font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
                        }
                        .accessibilityElement(children: .ignore).accessibilityLabel("\(game.totalStars) of \(maximumStars) stars").accessibilityIdentifier("total-stars")
                    }
                }
                Text(introduction)
                    .font(.system(size: 14)).foregroundStyle(Palette.secondary).lineSpacing(3)
                if let notice = game.migrationNotice {
                    Text(notice).font(.footnote).foregroundStyle(Palette.secondary)
                        .padding(13).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.faint.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                }
                if let error = game.saveError {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(error).font(.footnote).foregroundStyle(Palette.clay)
                        if game.hasUnreadableSave {
                            Button("Preserve file & begin again") { confirmRecovery = true }
                                .buttonStyle(PaperButtonStyle()).accessibilityIdentifier("recover-progress")
                        }
                    }
                }
                if !inSheet {
                    Button { game.resume() } label: {
                        HStack {
                            Text(game.state.revision > 0 ? "Continue level \(game.state.levelIndex + 1)" : "Play level \(game.state.levelIndex + 1)")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }.padding(.horizontal, 17)
                    }.buttonStyle(PaperButtonStyle(filled: true)).disabled(game.hasUnreadableSave)
                        .accessibilityIdentifier("continue")
                }
                VStack(alignment: .leading, spacing: 13) {
                    chapterNavigation
                    if let first = chapterLevels.first, !game.isUnlocked(first.index), !game.hasUnreadableSave {
                        Text("Complete level \(first.index) to open this chapter.")
                            .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                        ForEach(chapterLevels, id: \.index) { level in
                            levelButton(level)
                        }
                    }
                }
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "star.circle").font(.system(size: 20, weight: .light)).foregroundStyle(Palette.gold)
                    Text("Any win opens the next island. Three stars reward the lowest coin cost. Your best score always stays.")
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(3)
                }
            }.padding(22).padding(.top, inSheet ? 0 : 12).padding(.bottom, 12)
        }
        .background(Palette.paper)
        .accessibilityIdentifier("level-map-scroll")
        .onChange(of: game.state.levelIndex) { _, _ in selectedChapter = nil }
        .confirmationDialog("Switch levels?", isPresented: $confirmSwitch, titleVisibility: .visible) {
            Button("Switch level") {
                if let index = pendingLevel { game.startLevel(index) }
                pendingLevel = nil
            }
            Button("Keep this layout", role: .cancel) { pendingLevel = nil }
        } message: {
            Text("The current layout will be replaced. Earned stars and unlocked levels remain saved.")
        }
        .alert("Begin new progress?", isPresented: $confirmRecovery) {
            Button("Preserve file and begin", role: .destructive) { game.recoverProgress() }
            Button("Keep current file", role: .cancel) { }
        } message: {
            Text("The unreadable file will be kept separately before new progress is created. Its stars cannot be loaded into this new campaign.")
        }
    }

    private func chapterRange(_ index: Int) -> String {
        let first = index * levelsPerChapter + 1
        let last = min((index + 1) * levelsPerChapter, Balance.levels.count)
        return "\(first)–\(last)"
    }

    private var chapterNavigation: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Chapter \(chapterIndex + 1)")
                    .font(.custom("Georgia", fixedSize: 23))
                    .accessibilityLabel("Chapter \(chapterIndex + 1) of \(chapterCount)")
                    .accessibilityIdentifier("chapter-title")
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "star.fill").foregroundStyle(Palette.gold)
                    Text("\(chapterStars) / \(chapterLevels.count * 3)").monospacedDigit()
                }.font(.system(size: 12, weight: .semibold, design: .rounded))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(chapterStars) of \(chapterLevels.count * 3) stars in this chapter")
                    .accessibilityIdentifier("chapter-stars")
            }
            HStack(spacing: 9) {
                Button { selectedChapter = chapterIndex - 1 } label: {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                        .frame(width: 44, height: 44).background(Palette.faint.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).disabled(chapterIndex == 0)
                    .accessibilityLabel("Previous chapter").accessibilityIdentifier("previous-chapter")
                Menu {
                    ForEach(0..<chapterCount, id: \.self) { index in
                        Button {
                            selectedChapter = index
                        } label: {
                            if index == chapterIndex {
                                Label("Chapter \(index + 1) · Levels \(chapterRange(index))", systemImage: "checkmark")
                            } else {
                                Text("Chapter \(index + 1) · Levels \(chapterRange(index))")
                            }
                        }.accessibilityIdentifier("chapter-\(index + 1)")
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Levels \(chapterRange(chapterIndex))")
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold))
                    }.font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Palette.faint.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                }.accessibilityLabel("Choose chapter, levels \(chapterRange(chapterIndex))")
                    .accessibilityIdentifier("chapter-picker")
                Button { selectedChapter = chapterIndex + 1 } label: {
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                        .frame(width: 44, height: 44).background(Palette.faint.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).disabled(chapterIndex == chapterCount - 1)
                    .accessibilityLabel("Next chapter").accessibilityIdentifier("next-chapter")
            }
        }
    }

    private func levelButton(_ level: LevelDefinition) -> some View {
        let unlocked = game.isUnlocked(level.index)
        let stars = game.bestStars(for: level.index)
        let isCurrent = game.state.levelIndex == level.index
        return Button {
            if isCurrent { game.sheet = nil; game.resume() }
            else if game.state.revision > 0 && game.currentResult == nil { pendingLevel = level.index; confirmSwitch = true }
            else { game.startLevel(level.index) }
        } label: {
            VStack(spacing: 7) {
                HStack {
                    Text(String(format: "%02d", level.id)).font(.custom("Georgia", fixedSize: 26))
                    Spacer(minLength: 0)
                    if !unlocked { Image(systemName: "lock.fill").font(.system(size: 11)) }
                    else if isCurrent { Circle().fill(Palette.moss).frame(width: 5, height: 5) }
                }
                Text(level.title).font(.system(size: 10, weight: .semibold)).lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 25, alignment: .topLeading)
                StarRating(stars: stars, size: 11).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(13).frame(maxWidth: .infinity, minHeight: 106)
                .foregroundStyle(unlocked ? Palette.ink : Palette.secondary)
                .background(unlocked ? Palette.faint.opacity(isCurrent ? 0.7 : 0.32) : Palette.faint.opacity(0.17), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isCurrent ? Palette.ink.opacity(0.6) : Palette.faint, lineWidth: isCurrent ? 1.3 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Level \(level.id), \(level.title), \(unlocked ? "\(stars) of 3 stars" : "locked")")
        .accessibilityIdentifier("level-\(level.id)")
        .disabled(!unlocked)
    }
}
