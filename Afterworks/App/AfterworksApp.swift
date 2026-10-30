import SwiftUI

@main
struct AfterworksApp: App {
    @StateObject private var game = GameController()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            ContentView(game: game)
                .preferredColorScheme(.light)
                .tint(Palette.ink)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { game.interrupted() }
                }
        }
    }
}
