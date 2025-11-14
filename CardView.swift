import SwiftUI

struct CardView: View {
    @EnvironmentObject var cfg: LayoutConfig

    let rank: Rank
    let suit: Suit
    var cornerRadius: CGFloat = 10
    var borderWidth: CGFloat = 1.5
    var width: CGFloat = 100 // height derives from this

    private var height: CGFloat { width * cfg.cards.aspect }
    private var isRed: Bool { suit == .hearts || suit == .diamonds }
    private var rankColor: Color { isRed ? .red : .black }

    // Map suit to asset names added in Assets.xcassets
    private var suitAssetName: String {
        switch suit {
        case .spades:   return "suit_spade"
        case .hearts:   return "suit_heart"
        case .clubs:    return "suit_club"
        case .diamonds: return "suit_diamond"
        }
    }

    var body: some View {
        let corner = cfg.s(cfg.cards.cornerRadius)
        let stroke = cfg.s(cfg.cards.borderWidth)

        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(.white)
            RoundedRectangle(cornerRadius: corner)
                .stroke(Color(.sRGB, red: 0.06, green: 0.14, blue: 0.2, opacity: 1), lineWidth: stroke)

            VStack(spacing: 0) {
                // Top row: rank (left) and small suit (right)
                HStack(alignment: .firstTextBaseline) {
                    Text(rank.rawValue)
                        .font(.system(size: width * cfg.cards.rankFontRatio, weight: .bold, design: .rounded))
                        .foregroundStyle(rankColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, width * cfg.cards.sidePaddingRatio)

                    Image(suitAssetName)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: pixelSnapped(width * cfg.cards.smallSuitRatio), height: pixelSnapped(width * cfg.cards.smallSuitRatio))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, width * cfg.cards.sidePaddingRatio)
                }
                .padding(.top, width * cfg.cards.topPaddingRatio)

                Spacer(minLength: 0)

                // Center large suit
                Image(suitAssetName)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: pixelSnapped(width * cfg.cards.largeSuitRatio), height: pixelSnapped(width * cfg.cards.largeSuitRatio))

                Spacer(minLength: 0)
            }
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.08), radius: cfg.misc.boardShadowRadius, x: 0, y: cfg.misc.boardShadowYOffset)
    }

    // Snap to whole pixels to avoid soft rendering at small sizes
    private func pixelSnapped(_ value: CGFloat) -> CGFloat {
        #if os(iOS)
        let scale = UIScreen.main.scale
        #elseif os(macOS)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        #else
        let scale: CGFloat = 2.0
        #endif
        return CGFloat((value * scale).rounded()) / scale
    }
}

