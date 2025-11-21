import SwiftUI

struct BoardView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var cfg: LayoutConfig

    let mgzSize: CGSize
    let lzSize: CGSize
    let tzSize: CGSize
    let czSize: CGSize
    let rzSize: CGSize

    var body: some View {
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
                .foregroundStyle(.white)

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
            let isPassEnabled = (game.phase == .inRound && game.passAvailable)
            Button {
                game.usePass()
            } label: {
                Text("Pass")
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .frame(minWidth: 88)
                    .background(
                        Capsule()
                            .fill(
                                Color.green.opacity(isPassEnabled ? 0.92 : 0.05)
                            )
                    )
                    .foregroundStyle(
                        Color.white.opacity(isPassEnabled ? 1.0 : 0.55)
                    )
            }
            .buttonStyle(.plain)
            .animation(nil, value: isPassEnabled)
            .disabled(!isPassEnabled)
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
        GeometryReader { geo in
            let availableWidth = geo.size.width
            let availableHeight = geo.size.height
            let layout = LayoutMetrics(availableWidth: availableWidth, availableHeight: availableHeight, cfg: cfg)

            HStack(alignment: .top, spacing: layout.interColumnSpacing) {
                ForEach(game.columns.indices, id: \.self) { idx in
                    let col = game.columns[idx]
                    let canTap = game.phase == .inRound && !col.isLocked && game.currentCard != nil

                    VStack(spacing: 6) {
                        let hexStroke = hexTabStrokeColor(for: col)

                        HexTab()
                            .fill(Color.clear)
                            .overlay(HexTab().stroke(hexStroke, lineWidth: 3))
                            .frame(width: max(cfg.columns.hexTabMinWidth, layout.cardWidth * 0.62), height: cfg.columns.hexTabHeight)
                            .overlay(
                                Text("\(col.total)")
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            )
                            .offset(y: -2)

                        columnStack(col: col, layout: layout)
                            .frame(height: layout.columnFrameHeight - 8)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if canTap {
                                    game.placeCurrentCard(inColumn: idx)
                                }
                            }

                        bottomStatusPill(for: col)
                            .offset(y: -15)
                    }
                    .frame(width: layout.columnFrameWidth)
                }
            }
            .frame(width: availableWidth, height: availableHeight, alignment: .topLeading)
        }
    }

    private func columnPillBackgroundColor(for col: Column) -> Color {
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
        switch base {
        case .green:
            return Color(.sRGB, red: 0, green: 0.99, blue: 0, opacity: 1)
        case .yellow:
            return Color(.sRGB, red: 0.99, green: 0.99, blue: 0, opacity: 1)
        default:
            return Color(.sRGB, white: 0.7, opacity: 1)
        }
    }

    private func strokeWidth(for base: Color) -> CGFloat {
        if base == .green { return 3.5 }
        if base == .yellow { return 3.5 }
        return 1.0
    }

    private func columnFillColor(for col: Column) -> Color {
        if col.isLocked {
            return cfg.columns.columnFillLockedColor.opacity(cfg.columns.columnFillOpacity)
        }
        let isSoftState = (!col.isLocked && col.isSoft && !col.isFiveCardCharlie && col.total <= 21)
        if isSoftState {
            return cfg.columns.columnFillSoftColor.opacity(cfg.columns.columnFillOpacity)
        }
        return cfg.columns.columnFillNormalColor.opacity(cfg.columns.columnFillOpacity)
    }

    private func hexTabStrokeColor(for col: Column) -> Color {
        return columnPillBackgroundColor(for: col)
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
        let lineW = strokeWidth(for: pillColor)
        let fillColor = columnFillColor(for: col)

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: cfg.columns.columnCornerRadius)
                .fill(fillColor)

            RoundedRectangle(cornerRadius: cfg.columns.columnCornerRadius)
                .strokeBorder(strokeColor.opacity(cfg.columns.columnStrokeOpacity), lineWidth: lineW)

            VStack(spacing: 0) {
                Spacer(minLength: columnPadding)

                ZStack(alignment: .top) {
                    ForEach(Array(col.cards.enumerated()), id: \.element.id) { (i, card) in
                        CardView(rank: card.rank, suit: card.suit, width: W)
                            .offset(x: 0, y: overlapStep * CGFloat(i))
                    }
                }
                .frame(width: W, height: H, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .center)

                Spacer(minLength: fiveCardStackHeight - H + columnPadding)
            }
        }
        .frame(width: columnFrameWidth, height: columnFrameHeight)
    }

    private var rightZone: some View {
//        let layout = LayoutMetrics(
//            availableWidth: czSize.width,
//            availableHeight: czSize.height,
//            cfg: cfg
//        )
        //let hexWidth = max(cfg.columns.hexTabMinWidth, layout.cardWidth * 0.62)
        //let hexHeight = cfg.columns.hexTabHeight
        let (sum, _) = game.boardTotals()

        return VStack(alignment: .trailing, spacing: 10) {
            Text("Round Scores")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(.white)

            topThreeScores

            Button {
                game.takeScore()
            } label: {
                Text("Take Score:\n \(sum)")
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 11)
                            .fill(Color.green.opacity(
                                game.phase == .inRound ? 0.92 : 0.35
                            ))
                    )
                    .foregroundStyle(.white)
            }
            .disabled(!(game.phase == .inRound))
            .padding(.vertical, 10)
            .padding(.leading, 8)

            pick21Logo
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var pick21Logo: some View {
        Image("Pick21Logo-white")
            .resizable()
            .scaledToFit()
            .frame(height: 40)
            .padding(.horizontal, 8)
            .padding(.vertical, 0)
    }

    private func compactTotalBoxForRZ(hexWidth: CGFloat? = nil, hexHeight: CGFloat? = nil) -> some View {
        let (sum, _) = game.boardTotals()
        let layout = LayoutMetrics(availableWidth: czSize.width, availableHeight: czSize.height, cfg: cfg)
        let w = hexWidth ?? max(cfg.columns.hexTabMinWidth, layout.cardWidth * 0.62)
        let h = hexHeight ?? cfg.columns.hexTabHeight

        return HexTab()
            .fill(Color.blue.opacity(0))
            .overlay(HexTab().stroke(Color(.sRGB, white: 1, opacity: 0.5), lineWidth: 3))
            .frame(width: w, height: h)
            .overlay(
                Text("\(sum)")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            )
    }

    private var timerBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let progress = max(0, min(1, Double(game.timerValue) / Double(game.timerMax)))
            let fillWidth = CGFloat(progress) * w
            let corner = h / 2
            let badgeOverlap = h * cfg.hud.timerBadgeOverlapRatio

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: corner)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: corner)
                            .stroke(Color.gray.opacity(0.55), lineWidth: cfg.s(cfg.hud.timerTrackStroke))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: corner))

                RoundedRectangle(cornerRadius: corner)
                    .fill(LinearGradient(colors: [Color.green, Color.green.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, fillWidth))
                    .clipShape(RoundedRectangle(cornerRadius: corner))

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
        .frame(width: 100, alignment: .leading)
        .padding(2)
        .minimumScaleFactor(0.85)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.5), lineWidth: 3)
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
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.yellow.opacity(1))
                        Text("\(i + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.black)
                    }
                    .frame(width: 22, height: 22)
                    .padding(.leading, -3)

                    Text(game.roundScores[i].formatted())
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.white.opacity(0.45))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 6)
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
}

// MARK: - Layout Metrics driven by LayoutConfig
struct LayoutMetrics {
    let availableWidth: CGFloat
    let availableHeight: CGFloat
    let cfg: LayoutConfig

    var minCardWidth: CGFloat { cfg.s(cfg.cards.minWidth) }
    var maxCardWidth: CGFloat { cfg.s(cfg.cards.maxWidth) }
    var interColumnSpacing: CGFloat { cfg.s(cfg.columns.interColumnSpacing) }
    var minColumnChrome: CGFloat { cfg.s(cfg.columns.minColumnChrome) }
    var columnPaddingFraction: CGFloat { cfg.columns.columnPaddingFraction }
    var overlapFraction: CGFloat { cfg.columns.overlapFraction }

    var heightConstrainedCardWidth: CGFloat {
        let aspect = cfg.cards.aspect
        let denom = aspect * (1 + 4 * overlapFraction) + 2 * columnPaddingFraction
        guard denom > 0 else { return maxCardWidth }
        return availableHeight / denom
    }

    var widthConstrainedCardWidth: CGFloat {
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

struct HexTab: Shape {
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
