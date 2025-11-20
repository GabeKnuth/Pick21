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

    // Centering/scaling controls
    private let enableCentering: Bool = true
    private let enableScaling: Bool = true
    private let maxScale: CGFloat = 1.3
    private let horizontalMargin: CGFloat = 16
    private let verticalMargin: CGFloat = 12

    var body: some View {
        ZStack {
            // Force the bg image as the background
            GeometryReader { geo in
                Image("bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            if game.phase == .preGame {
                PreGameView()
                    .environmentObject(game)
                    .environmentObject(cfg)
                    .transition(.opacity)
            } else {
                GeometryReader { proxy in
                    // Compute centering and optional scale
                    let containerSize = proxy.size
                    let targetSize = mgzSize

                    // Available space after margins
                    let availW = max(0, containerSize.width - (enableCentering ? 2 * horizontalMargin : 0))
                    let availH = max(0, containerSize.height - (enableCentering ? 2 * verticalMargin : 0))

                    // Fit uniform scale if enabled
                    let fitScale: CGFloat = {
                        guard enableScaling else { return 1.0 }
                        guard targetSize.width > 0, targetSize.height > 0 else { return 1.0 }
                        let sW = availW / targetSize.width
                        let sH = availH / targetSize.height
                        let s = min(sW, sH)
                        return min(max(s, 1.0), maxScale) // never shrink below 1.0; cap growth
                    }()

                    // Positioning
                    let centerX = containerSize.width / 2
                    let centerY = containerSize.height / 2

                    // Treat coordinate system as landscape-left if not centering
                    let mgzOrigin = CGPoint(x: mgzOffsetFromLeft, y: 0)

                    ZStack {
                        // Board layer within MGZ: LZ, TZ, CZ, RZ
                        zonesInMGZ()
                            .allowsHitTesting(!showingOverlay)
                            .blur(radius: showingOverlay ? 1.0 : 0)

                        // Overlay layer centered within MGZ
                        if showingOverlay {
                            // Dimmed background over board
                            LinearGradient(
                                colors: [Color.black.opacity(0.55), Color.black.opacity(0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea()
                            .transition(.opacity)

                            // Full-frame interstitial that lives inside the MGZ frame
                            interstitialOverlay
                                .padding(.horizontal, 22)
                                .padding(.vertical, 18)
                                .transition(.scale.combined(with: .opacity))
                                .zIndex(1)
                        }
                    }
                    .frame(width: mgzSize.width, height: mgzSize.height, alignment: .topLeading)
                    .scaleEffect(fitScale, anchor: .center)
                    .position(
                        x: enableCentering ? centerX : (mgzOrigin.x + mgzSize.width / 2),
                        y: enableCentering ? centerY : (mgzOrigin.y + mgzSize.height / 2)
                    )
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showingOverlay)
        .ignoresSafeArea()
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
        let layout = LayoutMetrics(
            availableWidth: czSize.width,
            availableHeight: czSize.height,
            cfg: cfg
        )
        let hexWidth = max(cfg.columns.hexTabMinWidth, layout.cardWidth * 0.62)
        let hexHeight = cfg.columns.hexTabHeight
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

    // MARK: - Interstitials (Full-frame overlays)
    @ViewBuilder
    private var interstitialOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            let headerText: String = {
                if game.phase == .gameOver {
                    return "Game Over"
                } else {
                    let (sum, busted) = game.boardTotals()
                    if busted {
                        return "Round \(game.round): BUST"
                    } else {
                        return "Round \(game.round): \(sum)"
                    }
                }
            }()

            let header = HStack(spacing: 10) {
                Image(systemName: game.phase == .gameOver ? "flag.checkered" : "rosette")
                    .font(.system(size: min(w, h) * 0.05, weight: .bold))
                    .foregroundStyle(.white)
                Text(headerText)
                    .font(.system(size: min(w, h) * 0.06, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.95))
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
            )

            VStack(spacing: 16) {
                header

                if game.phase == .betweenRounds {
                    betweenRoundsContent
                } else {
                    gameOverContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, w * 0.06)
            .padding(.vertical, h * 0.06)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)
            .frame(width: w, height: h, alignment: .center)
        }
    }

    private var betweenRoundsContent: some View {
        VStack(spacing: 14) {
            Text("Round Score")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.black)

            Text("\(game.roundScores[max(0, game.round - 1)])")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 18) {
                Button {
                    game.nextRound()
                } label: {
                    Label("Start Next Round", systemImage: "play.fill")
                        .font(.headline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(Color.green.opacity(0.95))
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    game.startNewGame()
                } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(Color.white.opacity(0.2))
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    private var gameOverContent: some View {
        VStack(spacing: 14) {
            // Replace "Final Score" with "★ New High Score!" when appropriate
            Text(game.isNewHighScore ? "★ New High Score!" : "Final Score")
                .font(.system(.title3, design: .rounded).weight(.semibold))

            Text("\(game.totalScore)")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .monospacedDigit()

            // Removed the separate "New High Score!" label to avoid layout shift

            VStack(alignment: .leading, spacing: 6) {
                Text("Round Details")
                    .font(.headline)
                ForEach(0..<3, id: \.self) { i in
                    HStack {
                        Text("Round \(i + 1)")
                        Spacer()
                        Text("\(game.roundScores[i])").monospacedDigit()
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.12))
            )

            HStack(spacing: 18) {
                Button {
                    game.startNewGame()
                } label: {
                    Label("Play Again", systemImage: "arrow.triangle.2.circlepath")
                        .font(.headline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(Color.green.opacity(0.95))
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    game.returnToPreGame()
                } label: {
                    Label("Main Menu", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(Color.white.opacity(0.2))
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    // MARK: - Overlay Panels (legacy accessors kept but unused internally)
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

            Button("Play Again") { game.startNewGame() }
                .buttonStyle(.borderedProminent)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
    }
}

// MARK: - Pre-Game UI
private struct PreGameView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var cfg: LayoutConfig

    @State private var showingHighScores = false
    @State private var showingSettings = false

    // Tip store for the “Buy me a coffee” IAP
    @StateObject private var tipStore = TipStore(productID: "Pick21BuyMeCoffee")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                VStack(spacing: 18) {
                    Spacer()

                    VStack(spacing: 8) {
                        Image("Pick21Logo-white")
                            .resizable()
                            .scaledToFit()
                            .frame(height: min(80, h * 0.2))
                            .shadow(radius: 6, y: 3)
                            .offset(y: 20)

                    }

                    Spacer()

                    VStack(spacing: 12) {
                        Button {
                            game.startNewGame()
                        } label: {
                            Label("Play", systemImage: "play.fill")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .frame(maxWidth: 420)
                                .background(
                                    Capsule().fill(Color.green.opacity(0.95))
                                )
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingHighScores = true
                        } label: {
                            Label("View High Scores", systemImage: "trophy.fill")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .frame(maxWidth: 420)
                                .background(
                                    Capsule().fill(Color.white.opacity(0.18))
                                )
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showingHighScores) {
                            HighScoresSheet(entries: game.highScores.entries)
                        }

                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape.fill")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .frame(maxWidth: 420)
                                .background(
                                    Capsule().fill(Color.white.opacity(0.18))
                                )
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showingSettings) {
                            SettingsSheet(
                                hapticsEnabled: $game.hapticsEnabled,
                                deckCount: $game.deckCount,
                                clearAction: { game.clearHighScores() }
                            )
                            .presentationDetents([.medium, .large])
                        }
                    }

                    Spacer()

                    // Best score quick chip
                    let best = game.highScores.entries.first?.score ?? 0
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text("Best: \(best.formatted())")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.35)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .offset(y: -8)

                    Spacer()
                }
                .frame(width: w, height: h)
                .padding(.horizontal, 24)
                .background(
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                )

                // Floating “Buy me a coffee” control in lower-right
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        coffeeTipButton
                    }
                    .padding(.trailing, 35)
                    .padding(.bottom, 16)
                }
                .frame(width: w, height: h)
            }
        }
    }

    // MARK: Tip button
    private var coffeeTipButton: some View {
        // Button is enabled only when the product is ready
        let isEnabled: Bool = {
            if case .ready = tipStore.state { return true }
            return false
        }()

        // Label text: show "Thank you!" after purchase, otherwise the normal two-line copy
        let labelTextTop: String
        let labelTextBottom: String?
        if case .purchased = tipStore.state {
            labelTextTop = "Thank you!"
            labelTextBottom = nil
        } else {
            labelTextTop = "Like this game?"
            labelTextBottom = "Buy me a coffee!"
        }

        return Button {
            // Guard: only attempt purchase when ready
            if case .ready = tipStore.state {
                Task { await tipStore.purchase() }
            }
        } label: {
            HStack(spacing: 8) {
                Text("☕️")
                    .scaleEffect(2.0)
                    .padding(.trailing, 6)
                    .padding(.leading, 2)

                if let bottom = labelTextBottom {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(labelTextTop)
                            .foregroundStyle(.white)
                        Text(bottom)
                            .foregroundStyle(.yellow)
                    }
                } else {
                    // "Thank you!" single line, same overall layout footprint
                    Text(labelTextTop)
                        .foregroundStyle(.white)
                }
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    (tipStore.state == .purchased)
                    ? Color.green.opacity(0.35)
                    : Color.black.opacity(0.28)
                )
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .foregroundStyle(.white.opacity(0.95))
            .opacity(isEnabled ? 1.0 : 0.75) // subtle dim when disabled
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .task {
            await tipStore.load()
        }
        .accessibilityLabel("Buy me a coffee")
    }
}

private struct HighScoresSheet: View {
    let entries: [HighScoreEntry]
    @Environment(\.dismiss) private var dismiss
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if entries.isEmpty {
                        ContentUnavailableView("No High Scores", systemImage: "trophy", description: Text("Play a game to set your first high score."))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        HighScoresView(
                            entries: entries,
                            baseFontSize: 20,
                            rowVPadding: 0.5,
                            headerSpacing: 3
                        )
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle("High Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
        }
    }
}

private struct SettingsSheet: View {
    @Binding var hapticsEnabled: Bool
    @Binding var deckCount: Int
    let clearAction: () -> Void

    @State private var confirmClear = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Feedback") {
                    Toggle("Haptics", isOn: $hapticsEnabled)
                }

                Section {
                    Button(role: .destructive) {
                        confirmClear = true
                    } label: {
                        Label("Clear High Scores", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
            .alert("Clear all high scores?",
                   isPresented: $confirmClear) {
                Button("Clear High Scores", role: .destructive) {
                    clearAction()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }
}

// MARK: - Layout Metrics driven by LayoutConfig
private struct LayoutMetrics {
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

struct HighScoresView: View {
    let entries: [HighScoreEntry]
    var baseFontSize: CGFloat = 20
    var rowVPadding: CGFloat = 4
    var headerSpacing: CGFloat = 6

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none
        return df
    }()

    var body: some View {
        let maxRows = 10
        let shown = Array(entries.prefix(maxRows))
        let placeholderCount = max(0, maxRows - shown.count)

        VStack(alignment: .leading, spacing: headerSpacing) {
            if entries.isEmpty {
                Text("No scores yet.")
                    .font(.system(size: baseFontSize, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: max(0, rowVPadding)) {
                    HStack(spacing: 12) {
                        Text("Rank")
                            .font(.system(size: baseFontSize, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Score")
                            .font(.system(size: baseFontSize, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Date")
                            .font(.system(size: baseFontSize, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ForEach(Array(shown.enumerated()), id: \.element.id) { idx, entry in
                        rowView(rank: idx + 1,
                                scoreText: entry.score.formatted(),
                                dateText: dateFormatter.string(from: entry.date),
                                isPlaceholder: false)
                    }

                    ForEach(0..<placeholderCount, id: \.self) { idx in
                        rowView(rank: shown.count + idx + 1,
                                scoreText: "—",
                                dateText: "—",
                                isPlaceholder: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func rowView(rank: Int, scoreText: String, dateText: String, isPlaceholder: Bool) -> some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.system(size: baseFontSize, weight: .regular, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(scoreText)
                .font(.system(size: baseFontSize, weight: .regular, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(dateText)
                .font(.system(size: baseFontSize, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, max(0, rowVPadding))
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground).opacity(isPlaceholder ? 0.45 : 0.8))
        )
        .opacity(isPlaceholder ? 0.7 : 1.0)
    }
}
