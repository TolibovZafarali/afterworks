import SwiftUI
import AfterworksCore

struct GameSheets: View {
    @ObservedObject var game: GameController
    let kind: GameSheet
    @State private var confirmRestart = false

    var body: some View {
        NavigationStack {
            Group {
                if kind == .levels {
                    LevelMapView(game: game, inSheet: true)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 23) {
                            saveStatus
                            switch kind {
                            case .menu: menu
                            case .guide: guide
                            case .inspection: inspection
                            case .tiles: tileList
                            case .result: result
                            case .levels: EmptyView()
                            }
                        }.padding(24).padding(.top, 5)
                    }
                }
            }
            .background(Palette.paper).foregroundStyle(Palette.ink)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { game.sheet = nil }.fontWeight(.semibold).accessibilityIdentifier("sheet-done")
                }
            }
            .toolbarBackground(Palette.paper, for: .navigationBar)
            .alert("Restart this level?", isPresented: $confirmRestart) {
                Button("Restart level", role: .destructive) { game.restart() }
                Button("Keep planning", role: .cancel) { }
            } message: {
                Text("Restore this island and its gold coins. Your best stars and unlocked levels stay saved.")
            }
        }
    }

    @ViewBuilder
    private var saveStatus: some View {
        if let error = game.saveError {
            VStack(alignment: .leading, spacing: 10) {
                Label("Progress needs saving", systemImage: "exclamationmark.circle")
                    .font(.system(size: 15, weight: .semibold))
                Text(error).font(.footnote).fixedSize(horizontal: false, vertical: true)
                Text("Your changes are available in this session. Save them before closing the game.")
                    .font(.footnote).fixedSize(horizontal: false, vertical: true)
                Button("Try saving again") { game.persist() }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(minHeight: 44).accessibilityIdentifier("retry-save")
            }
            .foregroundStyle(Palette.clay).padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.clay.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("save-error")
        }
    }

    private var menu: some View {
        Group {
            SheetHeading(eyebrow: "Level \(game.state.levelIndex + 1) of 12", title: "Take a breath.")
            Text(game.saveError == nil ? "Your plan and best stars are saved on this device. Pick up exactly where you left off." : "Your plan and stars are available in this session. Save successfully to keep them for your next visit.")
                .font(.subheadline).foregroundStyle(Palette.secondary)
            VStack(spacing: 0) {
                menuRow("Goal & hints", icon: "lightbulb") { game.sheet = .guide }
                menuRow("Accessible tile list", icon: "square.grid.3x3") { game.sheet = .tiles }
                if game.state.board.tiles.contains(where: { $0.terrain == .woodland }) {
                    menuRow("Clear woodland · \(Balance.clearingCost) coins", icon: "leaf") { game.sheet = nil; game.select(.clear) }
                }
            }
            VStack(spacing: 16) {
                Toggle(isOn: $game.settings.sound) { Label("Sound", systemImage: "speaker.wave.2") }
                    .accessibilityIdentifier("sound-toggle")
                Toggle(isOn: $game.settings.haptics) { Label("Haptics", systemImage: "hand.tap") }
                    .accessibilityIdentifier("haptics-toggle")
            }.font(.system(size: 15, weight: .medium)).onChange(of: game.settings) { _, _ in game.persist() }
            Divider().overlay(Palette.faint)
            VStack(spacing: 0) {
                menuRow("Restart level", icon: "arrow.counterclockwise") {
                    if game.state.revision > 0 { confirmRestart = true } else { game.restart() }
                }.accessibilityIdentifier("restart-level")
                menuRow("All levels", icon: "square.grid.2x2") { game.goHome() }.accessibilityIdentifier("levels")
            }
            Text("Each island starts fresh. Earn any star to unlock the next one, then return for a thriftier solution.")
                .font(.footnote).foregroundStyle(Palette.secondary)
        }
    }

    private func menuRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon).frame(width: 22)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.secondary)
            }.font(.system(size: 15, weight: .medium)).frame(minHeight: 48).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private var guide: some View {
        Group {
            SheetHeading(eyebrow: "Field notes · Level \(game.state.levelIndex + 1)", title: game.level.title)
            Text(game.level.subtitle).font(.system(size: 16, weight: .semibold))
            note("YOUR ORDER", game.level.order.summary)
            note("A LITTLE NUDGE", game.level.hint)
            VStack(alignment: .leading, spacing: 12) {
                scoreRow(stars: 3, text: "\(game.level.minimumCoins) coins or fewer")
                scoreRow(stars: 2, text: "\(game.level.twoStarCoins) coins or fewer")
                scoreRow(stars: 1, text: "Complete within \(game.level.budget) coins")
            }
            note("MAKE A CONNECTION", "Every producer needs a route containing at least one road tile to the depot. Being beside the depot is not enough. Roads join along edges; diagonals and other buildings never carry traffic. Bridges can be part of a route across water or wetland.")
            note("YOUR GOLD COINS", "The gold coin counter is the amount left for this level. Tap a piece and then a highlighted tile, or drag it onto the island. Drag across the board with Road selected to lay one undoable stroke. Removing a piece refunds all of its coins.")
            note("SPEND LESS, EARN MORE", "Stars use the coins spent on your successful plan. Undo and refunds let you experiment freely. Clearing woodland costs coins and produces no timber; undo restores it. Your best result always stays saved, even after a less efficient replay.")
            note("DISPATCH", "Each valid connected producer delivers once per check. Repeating Dispatch gives the same totals. An incomplete order lets you keep planning. Edit a completed layout and dispatch again to improve its stars.")
            note("KNOW YOUR GROUND", "Cliffs are impassable and cannot be quarried or cleared. Quarries need pale stone ground. Water and wetland crossings require bridges. Clearing woodland costs \(Balance.clearingCost) coins. Every new level has its own island, pieces, and coin budget.")
            ForEach(game.level.availablePieces) { piece in
                let d = Balance.definition(for: piece)
                HStack(alignment: .top, spacing: 14) {
                    PieceGlyph(piece: piece.visual).frame(width: 45, height: 45)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Text(d.title).font(.system(size: 16, weight: .semibold))
                            CoinGlyph(size: 13)
                            Text("\(d.cost)").font(.system(size: 14, weight: .semibold))
                        }
                        Text(d.rule).font(.subheadline)
                        Text("\(game.level.limit(for: piece)) available in this level.").font(.footnote).foregroundStyle(Palette.secondary)
                    }
                }
            }
            if let evaluation = game.state.evaluation {
                Divider()
                SheetHeading(eyebrow: "Last dispatch", title: evaluation.meetsOrder ? "Order fulfilled." : "A little more to do.")
                Text(evaluation.totals.summary.isEmpty ? "No connected goods yet." : evaluation.totals.summary).font(.system(size: 17, weight: .semibold))
                ForEach(evaluation.producers) { producer in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(producer.position.label) · \(producer.piece.title)").font(.subheadline.bold())
                        Text(producer.reason).font(.subheadline).foregroundStyle(Palette.secondary)
                        if producer.worked {
                            Text("Route: \(producer.route.map(\.label).joined(separator: " → "))")
                                .font(.caption).foregroundStyle(Palette.secondary)
                        }
                    }
                }
            }
        }
    }

    private func note(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.system(size: 10, weight: .bold)).tracking(1.4).foregroundStyle(Palette.secondary)
            Text(text).font(.system(size: 15)).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func scoreRow(stars: Int, text: String) -> some View {
        HStack(spacing: 15) {
            StarRating(stars: stars, size: 15)
            Text(text).font(.system(size: 13, weight: .medium))
        }
    }

    @ViewBuilder
    private var inspection: some View {
        if let p = game.inspected {
            let tile = game.state.board[p]
            let producer = game.liveEvaluation.producers.first { $0.position == p }
            SheetHeading(eyebrow: "Tile \(p.label) · Island notes", title: p == game.state.board.depot ? "The depot" : tile.building?.title ?? tile.infrastructure?.title ?? tile.terrain.title)
            if let piece = tile.building ?? tile.infrastructure {
                HStack(spacing: 18) {
                    PieceGlyph(piece: piece.visual).frame(width: 70, height: 70)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tile.terrain.title).font(.system(size: 17, weight: .semibold))
                        Text(Balance.definition(for: piece).rule).font(.subheadline).foregroundStyle(Palette.secondary)
                    }
                }
            } else { Text(tile.terrain.description).font(.subheadline).lineSpacing(4) }
            if p == game.state.board.depot {
                note("THE WAY HOME", "All goods arrive here by road. A producer beside the depot still needs a route through at least one road tile. The depot cannot be moved.")
            }
            if let producer {
                note(producer.worked ? "CONNECTED & WORKING" : "NOT PRODUCING", producer.reason)
                if producer.worked { note("ACTUAL ROUTE", producer.route.map(\.label).joined(separator: " → ")) }
            }
            if tile.building != nil || tile.infrastructure != nil {
                Button {
                    game.sheet = nil
                    game.perform(.remove(p))
                } label: {
                    HStack(spacing: 6) {
                        Text("Remove piece · refund")
                        CoinGlyph(size: 15)
                        Text("\(Balance.definition(for: (tile.building ?? tile.infrastructure)!).cost)")
                    }
                }.buttonStyle(PaperButtonStyle()).accessibilityIdentifier("remove-inspected")
            } else if tile.terrain == .woodland {
                Button("Clear woodland · \(Balance.clearingCost) coins") {
                    game.sheet = nil
                    game.perform(.clearWoodland(p))
                }.buttonStyle(PaperButtonStyle()).accessibilityIdentifier("clear-inspected")
            }
        }
    }

    private var tileList: some View {
        Group {
            SheetHeading(eyebrow: "An accessible island", title: "Every tile, in reach.")
            Text("Choose an action, then a tile. Rows run from north to south; columns A to G run west to east.")
                .font(.subheadline).foregroundStyle(Palette.secondary)
            Menu {
                Button("Inspect") { game.select(.inspect) }
                Button("Remove") { game.select(.remove) }
                if game.state.board.tiles.contains(where: { $0.terrain == .woodland }) {
                    Button("Clear woodland") { game.select(.clear) }
                }
                ForEach(game.level.availablePieces) { piece in
                    Button("\(piece.title) · \(Balance.definition(for: piece).cost) coins") { game.select(.piece(piece)) }
                }
            } label: {
                HStack { Text(tileAction); Spacer(); Image(systemName: "chevron.down") }.padding(.horizontal, 14)
            }.buttonStyle(PaperButtonStyle()).accessibilityIdentifier("tile-action")
            Text(game.message).font(.footnote).foregroundStyle(game.messageIsError ? Palette.clay : Palette.secondary)
            LazyVStack(spacing: 0) {
                ForEach(Board.positions) { p in
                    let tile = game.state.board[p]
                    let producer = game.liveEvaluation.producers.first { $0.position == p }
                    Button { game.tap(p) } label: {
                        HStack(alignment: .center, spacing: 12) {
                            Text(p.label).font(.system(size: 15, weight: .bold, design: .monospaced)).frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p == game.state.board.depot ? "Depot" : tile.building?.title ?? tile.infrastructure?.title ?? tile.terrain.title)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(producer?.reason ?? tile.terrain.description).font(.caption).foregroundStyle(Palette.secondary).lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, minHeight: 62, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("tile-\(p.row)-\(p.col)")
                    Divider().overlay(Palette.faint)
                }
            }
        }
    }

    private var tileAction: String {
        switch game.tool {
        case let .piece(piece): return "Place \(piece.title.lowercased())"
        case .inspect: return "Inspect a tile"
        case .remove: return "Remove a piece"
        case .clear: return "Clear woodland"
        }
    }

    @ViewBuilder
    private var result: some View {
        if let result = game.currentResult {
            let finalLevel = game.state.levelIndex == Balance.levels.count - 1
            SheetHeading(eyebrow: "Level \(game.state.levelIndex + 1) complete", title: finalLevel ? "Twelve islands, delivered." : result.stars == 3 ? "Perfectly connected." : "Order delivered.")
                .accessibilityIdentifier("level-complete")
            StarRating(stars: result.stars, size: 49).frame(maxWidth: .infinity).padding(.vertical, 14)
                .accessibilityIdentifier("result-stars")
            HStack(alignment: .center, spacing: 13) {
                CoinGlyph(size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(result.coinsSpent) coins spent").font(.custom("Georgia", size: 26)).accessibilityIdentifier("result-spent")
                    Text("Three-star target: \(game.level.minimumCoins) coins").font(.system(size: 13)).foregroundStyle(Palette.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .center)
            if result.stars == 3 {
                Text("The whole order, for the fewest coins. Every connection earned its place.")
                    .font(.system(size: 16)).lineSpacing(5).foregroundStyle(Palette.secondary)
            } else {
                Text("\(finalLevel ? "The final order is delivered." : "Your delivery opened the next island.") Save \(max(0, result.coinsSpent - game.level.minimumCoins)) more coins to earn all three stars here.")
                    .font(.system(size: 16)).lineSpacing(5).foregroundStyle(Palette.secondary)
            }
            if game.bestStars(for: game.state.levelIndex) > result.stars {
                Text("Your best result: \(game.bestStars(for: game.state.levelIndex)) stars. Replaying never lowers it.")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.moss)
            }
            if finalLevel {
                note("YOUR COLLECTION", "\(game.totalStars) of 36 stars earned. Revisit any island to find an even better route.")
                Button("Choose an island") { game.goHome() }.buttonStyle(PaperButtonStyle(filled: true)).accessibilityIdentifier("levels")
            } else {
                Button { game.advance() } label: {
                    HStack { Text("Next level"); Image(systemName: "arrow.right") }
                }.buttonStyle(PaperButtonStyle(filled: true)).accessibilityIdentifier("next-level")
            }
            Button("Keep improving") { game.sheet = nil }.buttonStyle(PaperButtonStyle()).accessibilityIdentifier("keep-improving")
            HStack(spacing: 20) {
                Button("Retry level") { confirmRestart = true }.frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("retry-level")
                if !finalLevel {
                    Button("All levels") { game.goHome() }.frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("levels")
                }
            }.font(.system(size: 14, weight: .semibold))
            Text(game.saveError == nil ? "Best stars are saved. Replaying never lowers your score." : "These stars are earned in this session. Save them before closing the game.")
                .font(.footnote).foregroundStyle(Palette.secondary)
        } else {
            SheetHeading(eyebrow: "Your plan", title: "Ready when you are.")
            Text("Dispatch a complete order to earn stars.").font(.subheadline)
        }
    }
}
