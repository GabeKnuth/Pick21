import SwiftUI

// MARK: - Pre-Game UI
struct PreGameView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var cfg: LayoutConfig

    @State private var showingHighScores = false
    @State private var showingSettings = false
    @State private var showingInstructions = false

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
                            showingInstructions = true
                        } label: {
                            Label("How to Play", systemImage: "questionmark.circle.fill")
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
                        .sheet(isPresented: $showingInstructions) {
                            InstructionsSheet()
                                .presentationDetents([.medium, .large])
                        }

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
