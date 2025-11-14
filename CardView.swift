import SwiftUI

struct CardView: View {
    let rank: Rank
    let suit: Suit
    var cornerRadius: CGFloat = 10
    var borderWidth: CGFloat = 1.5
    var width: CGFloat = 100 // height derives from this

    private var height: CGFloat { width * 1.45 } // typical card aspect
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
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.white)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color(.sRGB, red: 0.06, green: 0.14, blue: 0.2, opacity: 1), lineWidth: borderWidth)

            VStack(spacing: 0) {
                // Top row: rank (left) and small suit (right)
                HStack(alignment: .firstTextBaseline) {
                    Text(rank.rawValue)
                        .font(.system(size: width * 0.22, weight: .bold, design: .rounded))
                        .foregroundStyle(rankColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, width * 0.08)

                    Image(suitAssetName)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: pixelSnapped(width * 0.20), height: pixelSnapped(width * 0.20))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, width * 0.08)
                }
                .padding(.top, width * 0.06)

                Spacer(minLength: 0)

                // Center large suit
                Image(suitAssetName)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: pixelSnapped(width * 0.5), height: pixelSnapped(width * 0.5))

                Spacer(minLength: 0)
            }
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
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
