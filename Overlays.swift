import SwiftUI

struct InterstitialOverlay: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var cfg: LayoutConfig

    var body: some View {
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
                    BetweenRoundsContent()
                        .environmentObject(game)
                        .environmentObject(cfg)
                } else {
                    GameOverContent()
                        .environmentObject(game)
                        .environmentObject(cfg)
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
}

private struct BetweenRoundsContent: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var cfg: LayoutConfig

    var body: some View {
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
}

private struct GameOverContent: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var cfg: LayoutConfig

    var body: some View {
        VStack(spacing: 14) {
            Text(game.isNewHighScore ? "★ New High Score!" : "Final Score")
                .font(.system(.title3, design: .rounded).weight(.semibold))

            Text("\(game.totalScore)")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .monospacedDigit()

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
}
