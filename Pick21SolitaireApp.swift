import SwiftUI

@main
struct Pick21SolitaireApp: App {
    @StateObject private var game = GameState()
    @StateObject private var layoutConfig = LayoutConfig()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .environmentObject(layoutConfig)
        }
    }
}
