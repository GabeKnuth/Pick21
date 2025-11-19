import SwiftUI

@main
struct Pick21SolitaireApp: App {
    @StateObject private var game = GameState()
    @StateObject private var layoutConfig = LayoutConfig()

    init() {
        // Show the "bg" asset as the app-wide background
        layoutConfig.backgroundStyle = .image(name: "bg", contentMode: .fill, opacity: 1.0)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .environmentObject(layoutConfig)
        }
    }
}

