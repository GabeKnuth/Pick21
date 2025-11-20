import UIKit

enum OrientationHelper {
    // No-op: we no longer force orientation at runtime because either landscape is acceptable.
    // Keeping this here for potential future use, but it should not be called at launch.
    static func forceLandscapeLeft() {
        // Intentionally left blank
    }

    // Optional guarded helper if you ever need it manually (not used at launch).
    static func enforceLandscapeLeftIfNeeded() {
        // Intentionally left blank
    }
}
