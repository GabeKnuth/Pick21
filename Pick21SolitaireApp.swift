import SwiftUI
import UIKit

@main
struct Pick21SolitaireApp: App {
    @StateObject private var game = GameState()
    @StateObject private var layoutConfig = LayoutConfig()

    init() {
        // Removed: Do not mutate @StateObject here.
        // Re-apply orientation on scene activation (helps cold launch/simulator)
        NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { _ in
            forceLandscapeLeft()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .environmentObject(layoutConfig)
                .onAppear {
                    // Nudge on first appearance
                    forceLandscapeLeft()
                }
        }
    }
}

// MARK: - Orientation force
private func forceLandscapeLeft() {
    if #available(iOS 16.0, *) {
        guard let windowScene = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else { return }
        let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscapeLeft)
        do {
            try windowScene.requestGeometryUpdate(prefs)
        } catch {
            // Fallback if request fails
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    } else {
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
    }
}
