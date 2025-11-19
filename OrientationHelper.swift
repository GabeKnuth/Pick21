import UIKit

enum OrientationHelper {
    static func forceLandscapeLeft() {
        guard let windowScene = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else { return }

        // Declare landscape-left as the preferred interface orientations for this scene
        let mask: UIInterfaceOrientationMask = .landscapeLeft

        // For iOS 16+, request a geometry update. This is the supported API.
        if #available(iOS 16.0, *) {
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
            try? windowScene.requestGeometryUpdate(preferences)
        } else {
            // For iOS 13–15, set the device orientation and ask UIKit to rotate.
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
}
