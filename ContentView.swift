import SwiftUI

struct ContentView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var cfg: LayoutConfig

    // Fixed zone sizes (points) as specified (landscape, notch on the left)
    private let mgzSize = CGSize(width: 782, height: 393) // W x H when device is landscape-left; spec lists 393 x 782; we’ll place using orientation-aware axes
    private let mgzOffsetFromLeft: CGFloat = 55

    private let lzSize = CGSize(width: 135, height: 393)
    private let tzSize = CGSize(width: 662, height: 70)
    private let czSize = CGSize(width: 512, height: 323)
    private let rzSize = CGSize(width: 135, height: 323)

    var body: some View {
        ZStack {
            configurableBackground
                .ignoresSafeArea()

            GeometryReader { proxy in
                // Treat coordinate system as landscape-left: X increases to the right, Y increases down.
                // MGZ is placed mgzOffsetFromLeft from the “left/top” edge in landscape-left, which is x = mgzOffsetFromLeft, y = 0.
                let mgzOrigin = CGPoint(x: mgzOffsetFromLeft, y: 0)

                // Build MGZ container with fixed size
                ZStack {
                    // Board layer within MGZ: LZ, TZ, CZ, RZ
                    zonesInMGZ()
                        .allowsHitTesting(!showingOverlay)
                        .blur(radius: showingOverlay ? 1.0 : 0)

                    // Overlay layer centered within MGZ
                    if showingOverlay {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()

                        overlayPanel
                            .padding(18)
                            .transition(.scale.combined(with: .opacity))
                            .zIndex(1)
                    }
                }
                .frame(width: mgzSize.width, height: mgzSize.height, alignment: .topLeading)
                .position(x: mgzOrigin.x + mgzSize.width / 2, y: mgzOrigin.y + mgzSize.height / 2)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showingOverlay)
        .ignoresSafeArea()
    }

    // MARK: - Configurable Background
    @ViewBuilder
    private var configurableBackground: some View {
        switch cfg.backgroundStyle {
        case .solid(let color):
            color
        case .linearGradient(let colors, let start, let end):
            LinearGradient(colors: colors, startPoint: start, endPoint: end)
        case .radialGradient(let colors, let center, let startRadius, let endRadius):
            RadialGradient(colors: colors, center: center, startRadius: startRadius, endRadius: endRadius)
        case .angularGradient(let colors, let center, let angle):
            AngularGradient(colors: colors, center: center, angle: angle)
        }
    }

    // MARK: - Derived
    private var showingOverlay: Bool {
        game.phase == .betweenRounds || game.phase == .gameOver
    }

    // MARK: - MGZ Zones Layout
    private func zonesInMGZ() -> some View {
        ZStack(alignment: .topLeading) {
            // Left Zone (LZ)
            leftZone
                .frame(width: lzSize.width, height: lzSize.height)
                .position(x: lzSize.width / 2, y: lzSize.height / 2) // left aligned to MGZ left

            // Top Zone (TZ) – top aligned to MGZ, left aligned to right side of LZ
            topZone
                .frame(width: tzSize.width, height: tzSize.height)
                .position(x: lzSize.width + tzSize.width / 2 - 8, y: tzSize.height / 2)

            // Center Zone (CZ) – bottom aligned to MGZ, top aligned to bottom of TZ, left aligned with right side of LZ
            centerZone
                .frame(width: czSize.width, height: czSize.height)
                .position(x: lzSize.width + czSize.width / 2, y: mgzSize.height - czSize.height / 2)

            // Right Zone (RZ) – make same height as CZ and align its top to the top of CZ
            
            rightZone
                .frame(width: rzSize.width, height: czSize.height)
                .position(x: lzSize.width + czSize.width + rzSize.width / 2,
                          y: mgzSize.height - czSize.height / 2)
                
        }
    }

    // MARK: - Zone Contents

    // LZ: Shoe, Round label, score chart (bonusLegend)
    private var leftZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Shoe/current card
            currentCardPanel(width: 100) // fixed width to fit zone; adjust if needed

            // Round label moved below the shoe
            Text("Round \(game.round)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.8)
                .frame(width: 100, alignment: .center)
                

            // Score chart
            bonusLegend
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
    }

    // TZ: Pass button, timer, High Score
    private var topZone: some View {
        HStack(spacing: 0) {
            // Pass
            Button {
                game.usePass()
            } label: {
                Text("Pass")
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .frame(minWidth: 88)
                    .background(Capsule().fill(Color.green.opacity(game.passAvailable && game.phase == .inRound && game.currentCard != nil ? 0.92 : 0.35)))
                    .foregroundStyle(.white)
            }
            .disabled(!(game.phase == .inRound && game.passAvailable && game.currentCard != nil))
            .padding(.trailing, 20)

            // Timer
            timerBar
                .frame(height: cfg.s(cfg.hud.timerBarHeight))
                .frame(maxWidth: 390)
                .padding(.top, -8)
                .padding(.horizontal, 10)

            // High score chip
            highScoreChip

        }
        .padding(.horizontal, 0)
        .padding(.top, 8)
    }

    // CZ: Columns, scores, soft overlay, status pills
    private var centerZone: some View {
        // Fill CZ both horizontally and vertically, no scroll, no extra padding
        GeometryReader { geo in
            let availableWidth = geo.size.width
            let availableHeight = geo.size.height
            let layout = LayoutMetrics(availableWidth: availableWidth, availableHeight: availableHeight, cfg: cfg)

            // Distribute five columns with fixed inter-column spacing; chrome stays same size
            HStack(alignment: .top, spacing: layout.interColumnSpacing) {
                ForEach(game.columns.indices, id: \.self) { idx in
                    let col = game.columns[idx]
                    let canTap = game.phase == .inRound && !col.isLocked && game.currentCard != nil

                    VStack(spacing: 6) {
                        // Chip (hex-tab style) — keep its size, centered to column
                        HexTab()
                            .fill(Color.blue.opacity(0.9))
                            .overlay(HexTab().stroke(Color(.sRGB, white: 0, opacity: 0.25), lineWidth: 1))
                            .frame(width: max(cfg.columns.hexTabMinWidth, layout.cardWidth * 0.62), height: cfg.columns.hexTabHeight)
                            .overlay(
                                Text("\(col.total)")
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            )
                            .offset(y: -2)

                        // Column area fills the full CZ height allotted to the column
                        columnStack(col: col, layout: layout)
                            .frame(height: layout.columnFrameHeight - 8) // exact height to fill CZ
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if canTap {
                                    game.placeCurrentCard(inColumn: idx)
                                }
                            }

                        // Bottom pill — same size, centered under the column
                        bottomStatusPill(for: col)
                            .offset(y: -15)
                    }
                    .frame(width: layout.columnFrameWidth) // ensure each column gets its computed width
                }
            }
            .frame(width: availableWidth, height: availableHeight, alignment: .topLeading)
        }
    }

    private func columnPillBackgroundColor(for col: Column) -> Color {
        // Mirrors the bottom pill state
        if col.isLocked {
            return .green
        }
        let isSoftState = (!col.isLocked && col.isSoft && !col.isFiveCardCharlie && col.total <= 21)
        if isSoftState {
            return .yellow
        }
        return Color(.sRGB, red: 237/255, green: 237/255, blue: 237/255, opacity: 1)
    }

    private func darkerBorderColor(from base: Color) -> Color {
        // Adjust per known bases to ensure good contrast
        switch base {
        case .green:
            return Color(.sRGB, red: 0, green: 0.55, blue: 0, opacity: 1) // darker green
        case .yellow:
            return Color(.sRGB, red: 0.75, green: 0.6, blue: 0, opacity: 1) // amber-ish darker yellow
        default:
            return Color(.sRGB, white: 0.6, opacity: 1) // darker gray
        }
    }

    private func strokeWidth(for base: Color) -> CGFloat {
        // Slightly thicker when locked, medium for soft, thin otherwise
        if base == .green { return 2.5 }
        if base == .yellow { return 2.5 }
        return 1.0
    }

    private func columnStack(col: Column, layout: LayoutMetrics) -> some View {
        let W = layout.cardWidth
        let H = layout.cardHeight
        let overlapStep = H * layout.overlapFraction
        let fiveCardStackHeight = H + 4.0 * overlapStep
        let columnPadding = layout.columnPadding
        let columnFrameWidth = max(W + columnPadding * 2, W + layout.minColumnChrome)
        let columnFrameHeight = (fiveCardStackHeight + columnPadding * 2) - 6

        let pillColor = columnPillBackgroundColor(for: col)
        let strokeColor = darkerBorderColor(from: pillColor)
            .opacity(cfg.columns.columnStrokeOpacity)
        let lineW = strokeWidth(for: pillColor)

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: cfg.columns.columnCornerRadius)
                .strokeBorder(strokeColor, lineWidth: lineW)

            VStack(spacing: 0) {
                Spacer(minLength: columnPadding)

                ZStack(alignment: .top) {
                    ForEach(Array(col.cards.enumerated()), id: \.element.id) { (i, card) in
                        CardView(rank: card.rank, suit: card.suit, width: W)
                            .offset(x: 0, y: overlapStep * CGFloat(i))
                    }
                    if col.cards.isEmpty {
                        Text("Tap to place")
                            .foregroundStyle(.secondary)
                            .font(.caption2)
                            .padding(.vertical, 4)
                    }
                }
                .frame(width: W, height: H, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .center)

                Spacer(minLength: fiveCardStackHeight - H + columnPadding)
            }
        }
        // Removed the old "Soft" top overlay to avoid duplication.
        .frame(width: columnFrameWidth, height: columnFrameHeight)
    }

    // RZ: Total card score (aligned with CZ columns), round scores, total score, Take Score, Pick21 Logo
    private var rightZone: some View {
        // Compute the same layout used by CZ to align the hex chip vertically
        let layout = LayoutMetrics(
            availableWidth: czSize.width,
            availableHeight: czSize.height,
            cfg: cfg
        )
        let hexWidth = max(cfg.columns.hexTabMinWidth, layout.cardWidth * 0.62)
        let hexHeight = cfg.columns.hexTabHeight

        return VStack(alignment: .trailing, spacing: 10) {
            // Compact total hex chip
            compactTotalBoxForRZ(hexWidth: hexWidth, hexHeight: hexHeight)

            // Round scores 1–3
            topThreeScores

            // Take Score button
            Button {
                game.takeScore()
            } label: {
                Text("Take Score")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 11)
                            .fill(Color.green.opacity(
                                game.phase == .inRound ? 0.92 : 0.35
                            ))
                    )
                    .foregroundStyle(.white)
            }
            .disabled(!(game.phase == .inRound))

            // Pick21 Logo placeholder
            pick21Logo
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxHeight: .infinity, alignment: .top) // <-- allow it to expand to the given height

    }


    private var pick21Logo: some View {
        // Placeholder vector logo; replace with Image("Pick21Logo") if you add an asset
        HStack(spacing: 6) {
            Image(systemName: "suit.spade.fill")
            Text("Pick21")
                .font(.headline.weight(.bold))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.12)))
    }

    private func compactTotalBoxForRZ(hexWidth: CGFloat? = nil, hexHeight: CGFloat? = nil) -> some View {
        let (sum, _) = game.boardTotals()

        // If not provided, compute using CZ layout
        let layout = LayoutMetrics(availableWidth: czSize.width, availableHeight: czSize.height, cfg: cfg)
        let w = hexWidth ?? max(cfg.columns.hexTabMinWidth, layout.cardWidth * 0.62)
        let h = hexHeight ?? cfg.columns.hexTabHeight

        return HexTab()
            .fill(Color.blue.opacity(0.9))
            .overlay(HexTab().stroke(Color(.sRGB, white: 0, opacity: 0.25), lineWidth: 1))
            .frame(width: w, height: h)
            .overlay(
                Text("\(sum)")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            )
    }

    // Existing components reused (timerBar, highScoreChip, currentCardPanel, bonusLegend, topThreeScores, bottomStatusPill, overlay)

    private var timerBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let progress = max(0, min(1, Double(game.timerValue) / Double(game.timerMax)))
            let fillWidth = CGFloat(progress) * w
            let corner = h / 2
            let badgeOverlap = h * cfg.hud.timerBadgeOverlapRatio

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: corner)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: corner)
                            .stroke(Color.gray.opacity(0.55), lineWidth: cfg.s(cfg.hud.timerTrackStroke))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: corner))

                // Fill
                RoundedRectangle(cornerRadius: corner)
                    .fill(LinearGradient(colors: [Color.green, Color.green.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, fillWidth))
                    .clipShape(RoundedRectangle(cornerRadius: corner))

                // Trailing value pill on top of the track
                HStack {
                    Spacer(minLength: 0)
                    Text("\(max(0, game.timerValue))")
                        .font(.system(size: h * cfg.hud.timerValueFontRatio, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.96))
                        .padding(.horizontal, h * cfg.hud.timerValuePillHPadRatio)
                        .padding(.vertical, h * cfg.hud.timerValuePillVPadRatio)
                        .background(
                            Capsule().fill(Color.black.opacity(0.92))
                                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        )
                        .padding(.trailing, h * cfg.hud.timerValuePillTrailingRatio)
                }

                // Clock badge overlapping left
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(Color.yellow, lineWidth: 5))
                        .shadow(radius: 0.5, y: 1)
                    Image(systemName: "clock.fill")
                        .foregroundStyle(Color.black.opacity(0.88))
                        .font(.system(size: h * 0.78))
                }
                .frame(width: h * cfg.hud.timerBadgeScale, height: h * cfg.hud.timerBadgeScale)
                .offset(x: -badgeOverlap)
            }
        }
    }

    private var highScoreChip: some View {
        let best = game.highScores.entries.first?.score ?? 0
        return HStack(spacing: 8) {
            Text("High\nScore")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
            Text(best.formatted())
                .font(.subheadline .monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.18)))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.blue.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color(.sRGB, white: 0, opacity: 0.25), lineWidth: 1.5)
        )
    }

    private func currentCardPanel(width: CGFloat) -> some View {
        VStack(spacing: 6) {
            if let c = game.currentCard {
                CardView(rank: c.rank, suit: c.suit, width: width)
            } else {
                CardView(rank: .ace, suit: .spades, width: width)
                    .opacity(0.15)
                    .overlay(Text("—").font(.title))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bonusLegend: some View {
        VStack(alignment: .leading, spacing: 5) {
            legendRow("105", "× 1000")
            legendRow("104", "× 500")
            legendRow("103", "× 400")
            legendRow("102", "× 300")
            legendRow("101", "× 250")
            legendRow("100", "× 200")
            legendRow("99",  "× 150")
            legendRow("98",  "× 100")
            legendRow("97",  "× 50")
        }
        .frame(width: 100, alignment: .leading) // match shoe card width
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func legendRow(_ total: String, _ mult: String) -> some View {
        HStack(spacing: 4) {
            Text(total)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 25, alignment: .trailing)
            Text("=")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(.yellow)
            Text(mult)
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .monospacedDigit()
    }

    private var topThreeScores: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: 6) {
                    ZStack {
                        Circle().fill(Color.yellow.opacity(0.95))
                        Text("\(i + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.black)
                    }
                    .frame(width: 22, height: 22)

                    Text(game.roundScores[i].formatted())
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Color.blue.opacity(0.14)))
                }
            }
        }
    }

    private func bottomStatusPill(for col: Column) -> some View {
        let pillBackground = columnPillBackgroundColor(for: col)

        let text: String
        let foreground: Color

        if col.isLocked {
            text = "LOCKED"
            foreground = .white
        } else if pillBackground == .yellow {
            text = "SOFT"
            foreground = .black
        } else {
            text = "HIT"
            foreground = .primary
        }

        return Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, cfg.columns.bottomPillHPad)
            .padding(.vertical, cfg.columns.bottomPillVPad)
            .background(Capsule().fill(pillBackground))
    }

    // MARK: - Overlay Panels
    @ViewBuilder
    private var overlayPanel: some View {
        if game.phase == .betweenRounds {
            betweenRoundsOverlay
        } else if game.phase == .gameOver {
            gameOverOverlay
        }
    }

    private var betweenRoundsOverlay: some View {
        VStack(spacing: 8) {
            Text("Round \(game.round) result")
                .font(.title3.weight(.bold))
            Text("Score: \(game.roundScores[game.round - 1])")
                .font(.headline)
            if game.roundEndReason != .none {
                Text(roundEndText)
                    .foregroundStyle(.orange)
                    .font(.subheadline)
            }
            Button("Start Next Round") { game.nextRound() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
    }

    private var gameOverOverlay: some View {
        VStack(spacing: 10) {
            Text("Game Over")
                .font(.title2).bold()
            Text("Final Score: \(game.totalScore)")
                .font(.title3)

            if game.isNewHighScore {
                Text("New High Score!")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Per-Round Scores:").bold()
                ForEach(0..<3, id: \.self) { i in
                    Text("Round \(i + 1): \(game.roundScores[i])")
                }
            }

            Divider().padding(.vertical, 4)

            ScrollView {
                HighScoresView(entries: game.highScores.entries)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)

            Button("Play Again") { game.startNewGame() }
                .buttonStyle(.borderedProminent)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
    }

    private var roundEndText: String {
        switch game.roundEndReason {
        case .bust: return "Round over: Bust"
        case .tookScore: return "Round over: Score taken"
        case .perfectBoard: return "Round over: Perfect board!"
        case .timerExpired: return "Round over: Time up"
        default: return ""
        }
    }
}

// MARK: - Layout Metrics driven by LayoutConfig
private struct LayoutMetrics {
    let availableWidth: CGFloat
    let availableHeight: CGFloat
    let cfg: LayoutConfig

    // Derived from config
    var minCardWidth: CGFloat { cfg.s(cfg.cards.minWidth) }
    var maxCardWidth: CGFloat { cfg.s(cfg.cards.maxWidth) }
    var interColumnSpacing: CGFloat { cfg.s(cfg.columns.interColumnSpacing) }
    var minColumnChrome: CGFloat { cfg.s(cfg.columns.minColumnChrome) }
    var columnPaddingFraction: CGFloat { cfg.columns.columnPaddingFraction } // already a fraction
    var overlapFraction: CGFloat { cfg.columns.overlapFraction }

    // Computed dimensions to exactly fill CZ without outer padding
    // 1) Height-constrained card width: ensure five-card stack + padding == availableHeight
    //    H + 4*(H*overlap) + 2*pad == availableHeight
    //    Let pad = columnPaddingFraction * W, and H = W * aspect
    //    => (W*aspect) * (1 + 4*overlap) + 2*(columnPaddingFraction * W) == availableHeight
    //    => W * [aspect * (1 + 4*overlap) + 2*columnPaddingFraction] == availableHeight
    //    => W_h = availableHeight / denom
    var heightConstrainedCardWidth: CGFloat {
        let aspect = cfg.cards.aspect
        let denom = aspect * (1 + 4 * overlapFraction) + 2 * columnPaddingFraction
        guard denom > 0 else { return maxCardWidth }
        return availableHeight / denom
    }

    // 2) Width-constrained card width: five columns + chrome + spacings == availableWidth
    //    Column frame width = max(W + 2*pad, W + minColumnChrome)
    //    We’ll assume W + 2*pad dominates (common case), but take max with chrome to be safe.
    var widthConstrainedCardWidth: CGFloat {
        // We can solve iteratively since pad depends on W.
        // Use a small fixed-point iteration to converge.
        var w = min(maxCardWidth, max(minCardWidth, availableWidth / 7.0))
        for _ in 0..<8 {
            let pad = max(8, w * columnPaddingFraction)
            let colFrame = max(w + 2 * pad, w + minColumnChrome)
            let total = 5 * colFrame + 4 * interColumnSpacing
            let scale = availableWidth / max(total, 1)
            w = min(maxCardWidth, max(minCardWidth, w * scale))
        }
        return w
    }

    // Final card width is the min of height- and width-constrained sizes
    var cardWidth: CGFloat {
        let w = min(heightConstrainedCardWidth, widthConstrainedCardWidth)
        return min(maxCardWidth, max(minCardWidth, w))
    }

    var cardHeight: CGFloat { cardWidth * cfg.cards.aspect }
    var columnPadding: CGFloat { max(8, cardWidth * columnPaddingFraction) }

    var columnFrameWidth: CGFloat {
        max(cardWidth + 2 * columnPadding, cardWidth + minColumnChrome)
    }

    var columnFrameHeight: CGFloat {
        let overlapStep = cardHeight * overlapFraction
        let fiveCardStackHeight = cardHeight + 4.0 * overlapStep
        return fiveCardStackHeight + 2 * columnPadding
    }
}

private struct HexTab: Shape {
    func path(in rect: CGRect) -> Path {
        let h = rect.height
        let cut = min(h * 0.45, rect.width * 0.22)
        var p = Path()
        p.move(to: CGPoint(x: cut, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        p.addLine(to: CGPoint(x: cut, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

// HighScoresView unchanged
struct HighScoresView: View {
    let entries: [HighScoreEntry]
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none
        return df
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("High Scores")
                .font(.headline)
            if entries.isEmpty {
                Text("No scores yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    HStack(spacing: 8) {
                        Text("\(entry.score)")
                            .frame(width: 90, alignment: .leading)
                        Text(dateFormatter.string(from: entry.date))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
