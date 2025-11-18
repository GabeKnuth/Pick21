import SwiftUI

@main
struct Pick21SolitaireApp: App {
    @StateObject private var game = GameState()
    @StateObject private var layoutConfig = LayoutConfig()

    init() {
        // Customize default background style here
        // e.g., a solid color:
        // layoutConfig.backgroundStyle = .solid(.black)

        // or a gradient:
        // layoutConfig.backgroundStyle = .linearGradient(
        //     colors: [.purple, .black],
        //     start: .topLeading,
        //     end: .bottomTrailing
        // )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .environmentObject(layoutConfig)
        }
    }
}
