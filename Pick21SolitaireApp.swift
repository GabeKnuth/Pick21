import SwiftUI
import UIKit

@main
struct Pick21SolitaireApp: App {
    @StateObject private var game = GameState()
    @StateObject private var layoutConfig = LayoutConfig()

    init() {
        NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Option B only: enforce one landscape on iPhone
            OrientationHelper.enforceLandscapeLeftIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .environmentObject(layoutConfig)
            // Do NOT force orientation here.
        }
    }
}
