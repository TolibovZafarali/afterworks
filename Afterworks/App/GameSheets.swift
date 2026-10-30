import SwiftUI
import AfterworksCore

struct GameSheets: View {
    @ObservedObject var game: GameController
    let kind: GameSheet
    @State private var confirmation: Confirmation?

    enum Confirmation: String, Identifiable {
        case restart, rewind, new
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    switch kind {
                    case .menu: menu
                    case .guide: guide
                    case .inspection: inspection
                    case .tiles: tileList
                    case .result: result
                    }
                }.padding(24).padding(.top, 5)
            }
            .background(Palette.paper)
            .foregroundStyle(Palette.ink)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { game.sheet = nil }.fontWeight(.semibold).accessibilityIdentifier("sheet-done")
                }
            }
            .toolbarBackground(Palette.paper, for: .navigationBar)
            .alert(confirmationTitle, isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })) {
                Button(confirmationAction, role: .destructive) {
                    switch confirmation {
                    case .restart: game.restart()
                    case .rewind: game.rewind()
                    case .new: game.begin()
                    case nil: break
                    }
                    confirmation = nil
                }
                Button("Cancel", role: .cancel) { confirmation = nil }
            } message: { Text(confirmationMessage) }
        }
    }

    private var confirmationTitle: String {
        switch confirmation {
        case .restart: return "Restart this era?"
        case .rewind: return "Return to the previous era?"
        case .new: return "Start a new journey?"
        case nil: return ""
        }
    }
    private var confirmationAction: String {
        switch confirmation {
        case .restart: return "Restart this era"
        case .rewind: return "Rewind"
        case .new: return "Replace journey"
        case nil: return "Continue"
        }
    }
    private var confirmationMessage: String {
        switch confirmation {
        case .restart: return "Undo this era’s construction and restore its starting budget. Your inherited terrain stays."
        case .rewind: return "Restore the previous era’s starting island and budget. Later construction and terrain will be undone."
        case .new: return "Replace your island and all its checkpoints."
        case nil: return ""
        }
    }

    private var menu: some View {
        Group {
            SheetHeading(eyebrow: "Take a breath", title: "Your journey")
            Text("Every change is saved on this device. Your island waits for you.")
                .font(.subheadline).foregroundStyle(Palette.secondary)
            VStack(spacing: 0) {
                menuRow("How to play", icon: "book.closed") { game.sheet = .guide }
                menuRow("Accessible tile list", icon: "square.grid.3x3") { game.sheet = .tiles }
                if game.journey?.finished != true {
                    menuRow("Clear woodland · \(Balance.clearingCost) build", icon: "leaf.slash") { game.sheet = nil; game.select(.clear) }
                }
            }
            VStack(spacing: 16) {
                Toggle(isOn: $game.settings.sound) {
                    Label("Sound", systemImage: "speaker.wave.2")
                }.accessibilityIdentifier("sound-toggle")
                Toggle(isOn: $game.settings.haptics) {
                    Label("Haptics", systemImage: "hand.tap")
                }.accessibilityIdentifier("haptics-toggle")
            }.font(.system(size: 15, weight: .medium)).onChange(of: game.settings) { _, _ in game.persist() }
            Divider().overlay(Palette.faint)
            VStack(spacing: 0) {
                menuRow("Restart era", icon: "arrow.counterclockwise") { confirmation = .restart }
                menuRow("Rewind one era", icon: "backward.end") { confirmation = .rewind }.disabled(game.journey?.canRewind != true)
                menuRow("New journey", icon: "plus") { confirmation = .new }
                menuRow("Save & return home", icon: "house") { game.goHome() }
            }
            Text("No clocks to race. No resources to farm. Dispatch checks your current plan once.")
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
            }
            .font(.system(size: 15, weight: .medium)).frame(minHeight: 48).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private var guide: some View {
        Group {
            SheetHeading(eyebrow: "Field notes · Era \(game.state.eraIndex + 1)", title: "Build with tomorrow in mind.")
            Text(game.scenario.subtitle).font(.system(size: 16, weight: .semibold))
            note("THIS ORDER", game.scenario.order.summary)
            note(game.state.eraIndex < 2 ? "WHAT COMES NEXT" : "YOUR LASTING LANDSCAPE", game.scenario.forecast)
            note("MAKE A CONNECTION", "Roads join along their edges. Diagonals do not connect. A producer must touch the depot or a road or bridge that reaches it. Other buildings never carry a route.")
            note("CONSTRUCTION", "The number beside BUILD is your only spending budget. Tap a piece, then a highlighted tile, or drag it onto the island. Drag along the board to lay a road in one undoable stroke. Removing a new piece refunds its full cost.")
            note("OLD LANDSCAPE", "Old roads and bridges are free to reuse. Removing either costs \(Balance.inheritedRemovalCost) construction. Woodland can be cleared for \(Balance.clearingCost), without gaining timber. Lakes and wetland cannot be moved or filled. Water and wetland crossings need bridges.")
            note("DISPATCH", "Each valid connected producer delivers once per check. Repeating Dispatch gives the same totals. Editing cancels a successful check; dispatch again before advancing. You can inspect idle sites to learn what is missing.")
            note("TIME", "Only valid, connected producers and reservoirs transform. Inactive buildings disappear, leaving their original terrain. All built roads and bridges survive. Preview uses exactly the same transformation as advancement and never spends construction.")
            ForEach(game.scenario.availablePieces) { piece in
                let d = Balance.definition(for: piece)
                HStack(alignment: .top, spacing: 14) {
                    PieceGlyph(piece: piece.visual).frame(width: 45, height: 45)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(d.title) · \(d.cost) build").font(.system(size: 16, weight: .semibold))
                        Text(d.rule).font(.subheadline)
                        Text("\(d.limit) available per era. \(d.legacy)").font(.footnote).foregroundStyle(Palette.secondary)
                    }
                }
            }
            if let evaluation = game.state.evaluation {
                Divider()
                SheetHeading(eyebrow: "Last dispatch", title: evaluation.meetsOrder ? "Order fulfilled." : "A little more to do.")
                Text(evaluation.totals.summary).font(.system(size: 17, weight: .semibold))
                ForEach(evaluation.producers) { producer in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(producer.position.label) · \(producer.piece.title)").font(.subheadline.bold())
                        Text(producer.reason).font(.subheadline).foregroundStyle(Palette.secondary)
                        if producer.worked, !producer.route.isEmpty {
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

    @ViewBuilder
    private var inspection: some View {
        if let p = game.inspected {
            let tile = game.state.board[p]
            let future = Rules.transformedBoard(game.state)[p]
            let producer = game.liveEvaluation.producers.first { $0.position == p }
            SheetHeading(eyebrow: "Tile \(p.label) · \(game.preview ? "Future preview" : "Island notes")", title: p == game.state.board.depot ? "The depot" : tile.building?.title ?? tile.infrastructure?.title ?? tile.terrain.title)
            if let piece = tile.building ?? tile.infrastructure {
                HStack(spacing: 18) {
                    PieceGlyph(piece: piece.visual).frame(width: 70, height: 70)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tile.terrain.title).font(.system(size: 17, weight: .semibold))
                        Text(tile.inheritedInfrastructure ? "An old route · free to reuse" : Balance.definition(for: piece).rule)
                            .font(.subheadline).foregroundStyle(Palette.secondary)
                    }
                }
            } else { Text(tile.terrain.description).font(.subheadline).lineSpacing(4) }
            if p == game.state.board.depot {
                note("THE WAY HOME", "All goods arrive here. This location stays the same through all three eras. A producer can connect directly from an adjacent tile.")
            }
            if let producer {
                note(producer.worked ? "CONNECTED & WORKING" : "NOT PRODUCING", producer.reason)
                if producer.worked {
                    note("ACTUAL ROUTE", producer.route.map(\.label).joined(separator: " → "))
                }
            }
            if p != game.state.board.depot {
                note("AFTER THIS ERA", futureDescription(tile: tile, future: future, producer: producer))
            }
            if !game.preview, game.journey?.finished != true {
                if tile.building != nil || tile.infrastructure != nil {
                    Button(tile.inheritedInfrastructure ? "Remove old route · \(Balance.inheritedRemovalCost) build" : "Remove piece · refund \(Balance.definition(for: (tile.building ?? tile.infrastructure)!).cost)") {
                        game.sheet = nil
                        game.perform(.remove(p))
                    }.buttonStyle(PaperButtonStyle()).accessibilityIdentifier("remove-inspected")
                } else if tile.terrain == .woodland {
                    Button("Clear woodland · \(Balance.clearingCost) build") {
                        game.sheet = nil
                        game.perform(.clearWoodland(p))
                    }.buttonStyle(PaperButtonStyle()).accessibilityIdentifier("clear-inspected")
                }
            } else if game.preview {
                Text("Preview is read-only. Return to planning to make changes.")
                    .font(.footnote).foregroundStyle(Palette.secondary)
            }
        }
    }

    private func futureDescription(tile: Tile, future: Tile, producer: ProducerResult?) -> String {
        if let structure = tile.building {
            if producer?.worked != true {
                return "This inactive \(structure.title.lowercased()) disappears. Its underlying \(tile.terrain.title.lowercased()) remains. Connect it to receive its legacy."
            }
            return Balance.definition(for: structure).legacy + " Future terrain: \(future.terrain.title.lowercased())."
        }
        if let infrastructure = tile.infrastructure { return Balance.definition(for: infrastructure).legacy }
        return "This \(tile.terrain.title.lowercased()) remains at the same coordinate."
    }

    private var tileList: some View {
        Group {
            SheetHeading(eyebrow: "An accessible island", title: "Every tile, in reach.")
            Text(game.journey?.finished == true ? "Your final landscape. Select a tile to inspect what remains." : game.preview ? "Future preview. Select a tile to inspect its present and future." : "Choose an action, then a tile. Rows run from north to south; columns A to G run west to east.")
                .font(.subheadline).foregroundStyle(Palette.secondary)
            if !game.preview && game.journey?.finished != true {
                Menu {
                    Button("Inspect") { game.select(.inspect) }
                    Button("Remove") { game.select(.remove) }
                    Button("Clear woodland") { game.select(.clear) }
                    ForEach(game.scenario.availablePieces) { piece in
                        Button("\(piece.title) · \(Balance.definition(for: piece).cost) build") { game.select(.piece(piece)) }
                    }
                } label: {
                    HStack { Text(tileAction); Spacer(); Image(systemName: "chevron.down") }
                }.buttonStyle(PaperButtonStyle()).accessibilityIdentifier("tile-action")
            }
            Text(game.message).font(.footnote).foregroundStyle(game.messageIsError ? Palette.clay : Palette.secondary)
            LazyVStack(spacing: 0) {
                ForEach(Board.positions) { p in
                    let tile = game.displayedBoard[p]
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

    private var result: some View {
        Group {
            SheetHeading(eyebrow: "Three eras complete", title: "A place that remembers.")
                .accessibilityIdentifier("journey-complete")
            Text("You built a settlement. Time made it a landscape.")
                .font(.custom("Georgia", size: 21)).lineSpacing(5)
            Text("The water holds the shape of your quarries. The woods remember your orchards. The routes still lead home.")
                .font(.system(size: 16)).lineSpacing(6).foregroundStyle(Palette.secondary)
            HStack(spacing: 0) {
                landscapeCount("LAKES", count: game.state.board.tiles.filter { $0.terrain == .water }.count, icon: "water.waves")
                landscapeCount("WOODS", count: game.state.board.tiles.filter { $0.terrain == .woodland }.count, icon: "tree")
                landscapeCount("WETLAND", count: game.state.board.tiles.filter { $0.terrain == .wetland }.count, icon: "leaf")
            }.padding(.vertical, 8)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<3) { era in
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.moss)
                        Text("Era \(era + 1) · \(Balance.scenarios[era].title)").font(.system(size: 14, weight: .semibold))
                    }
                }
            }
            note("ANOTHER POSSIBILITY", "A quarry on the other shore. An orchard one tile north. Try a different first plan and discover the island it leaves behind.")
            Button("Explore your island") { game.sheet = nil }.buttonStyle(PaperButtonStyle(filled: true)).accessibilityIdentifier("explore-island")
            Button("New journey") { confirmation = .new }.buttonStyle(PaperButtonStyle())
        }
    }

    private func landscapeCount(_ title: String, count: Int, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 22, weight: .light)).foregroundStyle(Palette.moss)
            Text("\(count)").font(.custom("Georgia", size: 29))
            Text(title).font(.system(size: 8, weight: .bold)).tracking(1)
        }.frame(maxWidth: .infinity)
    }
}
