import SwiftUI
import UIKit

final class LockedHostingController<Content: View>: UIHostingController<Content> {
    // Defer entirely to the system and Info.plist supported orientations.
    // Removing overrides prevents conflicts and launch flips.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        super.supportedInterfaceOrientations
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        super.preferredInterfaceOrientationForPresentation
    }
}
