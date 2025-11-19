import SwiftUI
import UIKit

final class LockedHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // iPhone: lock to notch-left
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .landscapeLeft
        }
        // iPad can be adjusted as needed
        return [.landscapeLeft, .landscapeRight]
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .landscapeLeft
    }
}
