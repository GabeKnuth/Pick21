import SwiftUI

struct ContentView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let layout = LayoutMetrics(availableWidth: availableWidth)

            ZStack {
                // Board layer
                boardLayer(layout: layout)
                    .allowsHitTesting(!showingOverlay)
                    .blur(radius: showingOverlay ? 1.0 : 0)

                // HUD layer
                VStack(spacing: 6) {
                    topHUD(layout: layout)
                    Spacer()
                }
                .padding(.horizontal, layout.outerHPad)
                .padding(.top, layout.outerVPad)

                // Overlay layer
                if showingOverlay {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()

                    overlayPanel
                        .padding(18)
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: showingOverlay)
        }
    }

    // MARK: - Derived
    private var showingOverlay: Bool {
        game.phase == .betweenRounds || game.phase == .gameOver
    }

    // MARK: - Board Layer (three panes)
    private func boardLayer(layout: LayoutMetrics) -> some View {
        HStack(alignment: .top, spacing: layout.mainHStackSpacing) {
            // Left: Round + Legend + Current Card ("shoe")
            leftPanel(layout: layout)
                .frame(minWidth: layout.leftPaneMinWidth, maxWidth: layout.leftPaneMaxWidth, alignment: .topLeading)

            // Center: Columns (single ScrollView: chip + column + pill per column)
            columnsArea(layout: layout)
                .frame(maxWidth: .infinity, alignment: .top)

            // Right: Sidebar (Round scores + compact Total + Take Score)
            rightSidebar(layout: layout)
                .frame(minWidth: layout.rightPaneMinWidth, maxWidth: layout.rightPaneMaxWidth, alignment: .topTrailing)
        }
        .padding(.horizontal, layout.outerHPad)
        .padding(.top, layout.hudReserveHeight + layout.outerVPad)
        .padding(.bottom, layout.outerVPad)
    }

    // MARK: - HUD
    private func topHUD(layout: LayoutMetrics) -> some View {
        HStack(spacing: 12) {
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

            // Timer bar
            timerBar
                .frame(height: 24)
                .frame(maxWidth: .infinity)

            // High score chip (best overall)
            highScoreChip
        }
    }

    private var timerBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let progress = max(0, min(1, Double(game.timerValue) / Double(game.timerMax)))
            let fillWidth = CGFloat(progress) * w
            let corner = h / 2
            let badgeOverlap = h * 0.65

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: corner)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: corner)
                            .stroke(Color.gray.opacity(0.55), lineWidth: 2)
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
                        .font(.system(size: h * 0.7, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.96))
                        .padding(.horizontal, h * 0.6)
                        .padding(.vertical, h * 0.18)
                        .background(
                            Capsule().fill(Color.black.opacity(0.92))
                                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        )
                        .padding(.trailing, h * 0.25)
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
                .frame(width: h * 1.45, height: h * 1.45)
                .offset(x: -badgeOverlap)
            }
        }
    }

    private var highScoreChip: some View {
        let best = game.highScores.entries.first?.score ?? 0
        return HStack(spacing: 8) {
            Text("High Score")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(best.formatted())
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.18)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.blue.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color(.sRGB, white: 0, opacity: 0.25), lineWidth: 1.5)
        )
    }

    // MARK: - Left Panel (Round + Legend + Current Card)
    private func leftPanel(layout: LayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Round \(game.round)")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.8)

            currentCardPanel(width: layout.cardWidth)
            bonusLegend
        }
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
        .padding(10)
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
        HStack(spacing: 8) {
            Text(total)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, alignment: .trailing)
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

    // MARK: - Columns Area (single horizontal ScrollView with aligned chip/column/pill)
    private func columnsArea(layout: LayoutMetrics) -> some View {
        let W = layout.cardWidth
        let H = layout.cardHeight
        let overlapStep = H * layout.overlapFraction
        let fiveCardStackHeight = H + 4.0 * overlapStep
        let columnPadding = layout.columnPadding
        let columnFrameWidth = max(W + columnPadding * 2, W + layout.minColumnChrome)
        let columnFrameHeight = fiveCardStackHeight + columnPadding * 2

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: layout.interColumnSpacing) {
                ForEach(game.columns.indices, id: \.self) { idx in
                    let col = game.columns[idx]
                    let canTap = game.phase == .inRound && !col.isLocked && game.currentCard != nil

                    VStack(spacing: 6) {
                        // Chip (hex-tab style)
                        HexTab()
                            .fill(Color.blue.opacity(0.9))
                            .overlay(HexTab().stroke(Color(.sRGB, white: 0, opacity: 0.25), lineWidth: 1))
                            .frame(width: max(54, W * 0.62), height: 26)
                            .overlay(
                                Text("\(col.total)")
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            )

                        // Column
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color(.sRGB, white: 0, opacity: 0.18), lineWidth: 1)

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
                        // Soft label floats above the top border without shifting layout
                        .overlay(alignment: .top) {
                            if col.isSoft && !col.isFiveCardCharlie && col.total <= 21 {
                                Text("Soft")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(.thinMaterial, in: Capsule())
                                    .offset(y: -14)
                                    .zIndex(1)
                            }
                        }
                        .frame(width: columnFrameWidth, height: columnFrameHeight)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if canTap {
                                game.placeCurrentCard(inColumn: idx)
                            }
                        }

                        // Bottom pill
                        bottomStatusPill(for: col)
                    }
                }
            }
            .padding(.horizontal, 2)
            // Center-only top inset: moves hex tabs + columns + bottom pills down
            .padding(.top, layout.columnsTopInset)
        }
    }

    private func bottomStatusPill(for col: Column) -> some View {
        let text: String
        let color: Color
        if col.isLocked {
            text = "LOCKED"
            color = .green
        } else if col.busted {
            text = "BUST"
            color = .red
        } else {
            text = "HIT"
            color = .gray
        }
        return Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Capsule().fill(color.opacity(0.28)))
    }

    // MARK: - Right Sidebar
    private func rightSidebar(layout: LayoutMetrics) -> some View {
        VStack(alignment: .trailing, spacing: 10) {
            topThreeScores // now shows current game's round scores
            compactTotalBox(layout: layout)
            Button {
                game.takeScore()
            } label: {
                Text("Take Score")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Color.green.opacity(game.phase == .inRound ? 0.92 : 0.35)))
                    .foregroundStyle(.white)
            }
            .disabled(!(game.phase == .inRound))
        }
        .frame(minWidth: layout.rightPaneMinWidth, maxWidth: layout.rightPaneMaxWidth)
    }

    // Round scores for the current game (round 1–3)
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

    private func compactTotalBox(layout: LayoutMetrics) -> some View {
        let (sum, _) = game.boardTotals()
        return VStack(alignment: .trailing, spacing: 6) {
            Text("Total")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.blue.opacity(0.9)))
                .foregroundStyle(.white)

            Text("\(sum)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color(white: 0.95)))
        }
        .frame(maxWidth: layout.rightPaneMaxWidth)
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

// MARK: - Layout Metrics (denser to fit all five columns on iPhone landscape)
private struct LayoutMetrics {
    // Input
    let availableWidth: CGFloat

    // Tunables (dense)
    let minCardWidth: CGFloat = 64
    let maxCardWidth: CGFloat = 160
    let interColumnSpacing: CGFloat = 4
    let mainHStackSpacing: CGFloat = 8
    let outerHPad: CGFloat = 8
    let outerVPad: CGFloat = 6
    let minColumnChrome: CGFloat = 12
    let columnPaddingFraction: CGFloat = 0.12
    let overlapFraction: CGFloat = 0.32

    // Center-only inset for the columns area
    let columnsTopInset: CGFloat = 30

    // Side pane sizing (narrower — shrunk to free room for cards)
    let leftPaneMinWidth: CGFloat = 120
    let leftPaneMaxWidth: CGFloat = 132
    let rightPaneMinWidth: CGFloat = 136
    let rightPaneMaxWidth: CGFloat = 148

    // HUD reserve (slightly tighter)
    let hudReserveHeight: CGFloat = 40

    // Derived
    var cardWidth: CGFloat {
        let budget = max(availableWidth - (outerHPad * 2), 320)

        var w = clamp((minCardWidth + maxCardWidth) / 2, minCardWidth, maxCardWidth)

        // First pass
        let chrome1 = minColumnChrome + (columnPaddingFraction * 2 * w)
        let columns1 = 5 * (w + chrome1) + 4 * interColumnSpacing
        let side1 = leftPaneMaxWidth + rightPaneMaxWidth + mainHStackSpacing * 2
        let total1 = columns1 + side1
        w = clamp(w * (budget / max(total1, 1)), minCardWidth, maxCardWidth)

        // Second pass
        let chrome2 = minColumnChrome + (columnPaddingFraction * 2 * w)
        let columns2 = 5 * (w + chrome2) + 4 * interColumnSpacing
        let side2 = leftPaneMaxWidth + rightPaneMaxWidth + mainHStackSpacing * 2
        let total2 = columns2 + side2
        w = clamp(w * (budget / max(total2, 1)), minCardWidth, maxCardWidth)

        return w
    }

    var cardHeight: CGFloat { cardWidth * 1.4 }
    var columnPadding: CGFloat { max(8, cardWidth * columnPaddingFraction) }

    private func clamp(_ x: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
        min(max(x, a), b)
    }
}

// MARK: - HexTab shape used by the column total chip
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

// HighScoresView kept unchanged
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
