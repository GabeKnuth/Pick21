import SwiftUI

@MainActor
final class LayoutConfig: ObservableObject {

    // Global proportional scale (applies to most constants via computed access)
    @Published var uiScale: CGFloat = 1.0

    // Cards
    struct CardTunables {
        var minWidth: CGFloat = 64
        var maxWidth: CGFloat = 180
        var aspect: CGFloat = 1.45
        var cornerRadius: CGFloat = 10
        var borderWidth: CGFloat = 1.5

        // Internal ratios relative to card width
        var topPaddingRatio: CGFloat = 0.06
        var sidePaddingRatio: CGFloat = 0.08
        var smallSuitRatio: CGFloat = 0.20
        var largeSuitRatio: CGFloat = 0.50
        var rankFontRatio: CGFloat = 0.22
    }

    // Columns and stacks
    struct ColumnTunables {
        var interColumnSpacing: CGFloat = 4
        var minColumnChrome: CGFloat = 12
        var columnPaddingFraction: CGFloat = 0.12
        var overlapFraction: CGFloat = 0.32
        var columnsTopInset: CGFloat = 30
        var hexTabMinWidth: CGFloat = 54
        var hexTabHeight: CGFloat = 26
        var softLabelYOffset: CGFloat = -14
        var columnCornerRadius: CGFloat = 8
        var columnStrokeOpacity: CGFloat = 0.18
        var bottomPillHPad: CGFloat = 8
        var bottomPillVPad: CGFloat = 5
    }

    // Panes
    struct PaneTunables {
        var leftPaneMinWidth: CGFloat = 120
        var leftPaneMaxWidth: CGFloat = 132
        var rightPaneMinWidth: CGFloat = 136
        var rightPaneMaxWidth: CGFloat = 148
        var mainHStackSpacing: CGFloat = 8
    }

    // HUD
    struct HUDTunables {
        var outerHPad: CGFloat = 8
        var outerVPad: CGFloat = 6
        var hudReserveHeight: CGFloat = 40
        var timerBarHeight: CGFloat = 18 // smaller than previous 24
        // Timer badge ratios
        var timerBadgeScale: CGFloat = 1.45  // badge size relative to bar height
        var timerBadgeOverlapRatio: CGFloat = 0.65 // how far badge overlaps left
        var timerTrackStroke: CGFloat = 2
        var timerValuePillHPadRatio: CGFloat = 0.6
        var timerValuePillVPadRatio: CGFloat = 0.18
        var timerValuePillTrailingRatio: CGFloat = 0.25
        var timerValueFontRatio: CGFloat = 0.70
    }

    // Other spacings
    struct MiscTunables {
        var boardShadowRadius: CGFloat = 4
        var boardShadowYOffset: CGFloat = 2
    }

    @Published var cards = CardTunables()
    @Published var columns = ColumnTunables()
    @Published var panes = PaneTunables()
    @Published var hud = HUDTunables()
    @Published var misc = MiscTunables()

    // Helpers to get scaled values
    func s(_ v: CGFloat) -> CGFloat { v * uiScale }
}

