import Foundation
import Combine
import UIKit
import CoreHaptics

@MainActor
final class GameState: ObservableObject {
    // MARK: - Published State
    @Published var columns: [Column] = Array(repeating: Column(), count: 5)
    @Published var currentCard: Card?
    @Published var round: Int = 1 // 1...3
    @Published var totalScore: Int = 0
    @Published var roundScores: [Int] = [0, 0, 0]
    @Published var roundEndReason: RoundEndReason = .none
    @Published var phase: GamePhase = .preGame
    @Published var timerValue: Int = 280
    @Published var passAvailable: Bool = true
    @Published var isNewHighScore: Bool = false
    @Published var highScores: ScoreTable = HighScoresStorage.load()

    // Settings
    @Published var hapticsEnabled: Bool = true

    // NEW: configurable number of decks in the shoe
    // Set this to 1 for the original feel, or 4 for longer rounds.
    @Published var deckCount: Int = 1

    // MARK: - Timer Config
    // Expose a single source of truth for the per-round timer maximum.
    // UI can use this to compute progress for the countdown bar.
    var timerMax: Int { 280 }

    // MARK: - Private
    private var shoe: [Card] = []
    private var timerCancellable: AnyCancellable?
    private var timerSource: Publishers.Autoconnect<Timer.TimerPublisher>?

    // Core Haptics
    private var hapticsEngine: CHHapticEngine?
    private var hapticsSupportChecked = false
    private var hapticsSupported = false

    // MARK: - Init
    init() {
        // Start in pre-game. No automatic startNewGame to let the user press Play.
        // If you want to auto-continue an unfinished game later, this is the place to load it.
    }

    // MARK: - Game Lifecycle
    func startNewGame() {
        totalScore = 0
        roundScores = [0, 0, 0]
        round = 1
        isNewHighScore = false
        shoe.removeAll()
        startRound()
    }

    func startRound() {
        columns = Array(repeating: Column(), count: 5)
        roundEndReason = .none
        passAvailable = true
        timerValue = timerMax
        phase = .inRound

        // Build a fresh shoe for each round using the current deckCount
        shoe = makeShoe(decks: max(1, deckCount))
        shuffleShoe()

        drawNextCard()
        startTimer()
    }

    func endRound(reason: RoundEndReason) {
        guard phase == .inRound else { return }
        roundEndReason = reason
        stopTimer()

        let (score, _) = calculateRoundScore()
        roundScores[round - 1] = score
        totalScore += score

        // Haptics: celebrate perfect board (covers 105 case during finalization)
        if reason == .perfectBoard {
            // Use distinct 105 pattern here as well
            perfect105Haptics()
        }

        // Transition phase
        if round < 3 {
            phase = .betweenRounds
        } else {
            // Compute and persist high score status before triggering haptics
            let isTop = highScores.insert(score: totalScore)
            isNewHighScore = isTop
            HighScoresStorage.save(highScores)

            // Haptics: when game over interstitial will show
            if isNewHighScore {
                highScoreHaptics() // celebratory tick
            } else {
                gameOverHaptics()  // simple “game over” tick
            }

            phase = .gameOver
        }
    }

    func nextRound() {
        guard phase == .betweenRounds else { return }
        round += 1
        startRound()
    }

    func returnToPreGame() {
        stopTimer()
        phase = .preGame
    }

    // MARK: - Shoe / Cards
    private func makeShoe(decks: Int) -> [Card] {
        var cards: [Card] = []
        for _ in 0..<decks {
            for suit in Suit.allCases {
                for rank in Rank.allCases {
                    cards.append(Card(rank: rank, suit: suit))
                }
            }
        }
        return cards
    }

    private func shuffleShoe() {
        // Fisher–Yates
        var arr = shoe
        if arr.count > 1 {
            for i in stride(from: arr.count - 1, through: 1, by: -1) {
                let j = Int.random(in: 0...i)
                if i != j {
                    arr.swapAt(i, j)
                }
            }
        }
        shoe = arr
    }

    private func ensureShoe() {
        // If we ever run out (unlikely), rebuild a fresh shoe with the same deckCount
        if shoe.isEmpty {
            shoe = makeShoe(decks: max(1, deckCount))
            shuffleShoe()
        }
    }

    func drawNextCard() {
        ensureShoe()
        currentCard = shoe.removeLast()
    }

    // MARK: - Actions
    func placeCurrentCard(inColumn index: Int) {
        guard phase == .inRound else { return }
        guard index >= 0 && index < columns.count else { return }
        guard let card = currentCard else { return }
        guard !columns[index].isLocked else { return }

        columns[index].add(card)
        currentCard = nil

        // Check bust
        if columns[index].busted {
            endRound(reason: .bust)
            return
        }

        // NEW: Auto-end when board total reaches 105, even if some columns are soft (not locked)
        let (sum, _) = boardTotals()
        if sum == 105 {
            // Haptics: distinct pattern for 105
            perfect105Haptics()
            endRound(reason: .perfectBoard)
            return
        }

        // Check perfect board (all locked and effectively 21)
        if columns.allSatisfy({ $0.isLocked && $0.effectiveTotal == 21 }) {
            endRound(reason: .perfectBoard)
            return
        }

        // Draw next card
        drawNextCard()
    }

    func takeScore() {
        guard phase == .inRound else { return }
        endRound(reason: .tookScore)
    }

    func usePass() {
        guard phase == .inRound else { return }
        guard passAvailable else { return }
        // Discard current card and draw a new one
        passAvailable = false
        drawNextCard()
    }

    // MARK: - Timer
    func startTimer() {
        stopTimer()
        let pub = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
        timerSource = pub
        timerCancellable = pub.sink { [weak self] _ in
            guard let self else { return }
            guard self.phase == .inRound else { return }
            // Decrease by 2 twice per second => -4 per second
            self.timerValue -= 2
            if self.timerValue <= 0 {
                self.timerValue = 0
                self.endRound(reason: .timerExpired)
            }
        }
    }

    func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        timerSource = nil
    }

    // MARK: - Scoring
    func boardTotals() -> (sum: Int, busted: Bool) {
        var busted = false
        let sum = columns.reduce(0) { partial, col in
            if col.busted { busted = true }
            return partial + col.effectiveTotal
        }
        return (sum, busted)
    }

    func multiplier(for boardTotal: Int) -> Int? {
        switch boardTotal {
        case 105: return 1000
        case 104: return 500
        case 103: return 400
        case 102: return 300
        case 101: return 250
        case 100: return 200
        case 99:  return 150
        case 98:  return 100
        case 97:  return 50
        default:  return nil
        }
    }

    func calculateRoundScore() -> (score: Int, boardTotal: Int) {
        let (sum, busted) = boardTotals()
        if busted { return (0, sum) }
        guard let mult = multiplier(for: sum) else { return (0, sum) }
        let score = max(0, timerValue) * mult
        return (score, sum)
    }

    // MARK: - High Scores
    func clearHighScores() {
        highScores.entries.removeAll()
        HighScoresStorage.save(highScores)
        isNewHighScore = false
    }

    // MARK: - Core Haptics setup
    private func ensureHapticsEngine() {
        if hapticsSupportChecked == false {
            hapticsSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
            hapticsSupportChecked = true
        }
        guard hapticsSupported else { return }

        if hapticsEngine == nil {
            do {
                let engine = try CHHapticEngine()
                engine.isAutoShutdownEnabled = true
                engine.stoppedHandler = { reason in
                    // Engine stops automatically; we'll recreate lazily if needed
                }
                engine.resetHandler = { [weak self] in
                    // Try to restart on reset
                    try? self?.hapticsEngine?.start()
                }
                try engine.start()
                hapticsEngine = engine
            } catch {
                // If engine init fails, mark unsupported for this session
                hapticsSupported = false
                hapticsEngine = nil
            }
        } else {
            // Ensure it's running
            do {
                try hapticsEngine?.start()
            } catch {
                // Try rebuilding once
                hapticsEngine = nil
                ensureHapticsEngine()
            }
        }
    }

    // MARK: - Haptics
    // Distinct, overt celebratory pattern for achieving 105:
    // - Two strong transient spikes ~80ms apart
    // - A short continuous rumble tail (~200ms) with a slight decay
    private func perfect105Haptics() {
        guard hapticsEnabled else { return }

        ensureHapticsEngine()
        guard hapticsSupported, let engine = hapticsEngine else {
            // Fallback: bold double-tap using impacts with a longer cadence
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.prepare()
            heavy.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                let rigid = UIImpactFeedbackGenerator(style: .rigid)
                rigid.prepare()
                rigid.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                let soft = UIImpactFeedbackGenerator(style: .soft)
                soft.prepare()
                soft.impactOccurred(intensity: 0.7)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                let rigid = UIImpactFeedbackGenerator(style: .rigid)
                rigid.prepare()
                rigid.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                let soft = UIImpactFeedbackGenerator(style: .soft)
                soft.prepare()
                soft.impactOccurred(intensity: 0.7)
            }
            return
        }

        do {
            var events: [CHHapticEvent] = []

            // First sharp peak
            events.append(
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                    ],
                    relativeTime: 0.0
                )
            )

            // Second sharp peak at 80ms
            events.append(
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                    ],
                    relativeTime: 0.08
                )
            )

            // Short rumble tail starting at 140ms for 200ms, decaying
            let tailStart: TimeInterval = 0.14
            let tailDuration: TimeInterval = 0.22
            var tailParams: [CHHapticParameterCurve] = []

            // Intensity decays from 0.8 to 0.2 across the duration
            let intensityCurve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: tailStart, value: 0.8),
                    .init(relativeTime: tailStart + tailDuration * 0.6, value: 0.5),
                    .init(relativeTime: tailStart + tailDuration, value: 0.2)
                ],
                relativeTime: 0
            )
            tailParams.append(intensityCurve)

            // Sharpness decays a bit too for a softer tail
            let sharpnessCurve = CHHapticParameterCurve(
                parameterID: .hapticSharpnessControl,
                controlPoints: [
                    .init(relativeTime: tailStart, value: 0.6),
                    .init(relativeTime: tailStart + tailDuration, value: 0.3)
                ],
                relativeTime: 0
            )
            tailParams.append(sharpnessCurve)

            events.append(
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [],
                    relativeTime: tailStart,
                    duration: tailDuration
                )
            )

            let pattern = try CHHapticPattern(events: events, parameterCurves: tailParams)
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: 0)
        } catch {
            // Fallback if anything fails
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.prepare()
            heavy.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                let rigid = UIImpactFeedbackGenerator(style: .rigid)
                rigid.prepare()
                rigid.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                let soft = UIImpactFeedbackGenerator(style: .soft)
                soft.prepare()
                soft.impactOccurred(intensity: 0.7)
            }
        }
    }

    // Celebration for new high score at game over (keep system "success")
    private func highScoreHaptics() {
        guard hapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    private func gameOverHaptics() {
        guard hapticsEnabled else { return }
        // A simple, noticeable tick for non-high-score game over
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - High Scores Storage
enum HighScoresStorage {
    private static let key = "Pick21Solitaire.HighScores"

    static func load() -> ScoreTable {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: key) {
            if let decoded = try? JSONDecoder().decode(ScoreTable.self, from: data) {
                return decoded
            }
        }
        return ScoreTable()
    }

    static func save(_ table: ScoreTable) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(table) {
            defaults.set(data, forKey: key)
        }
    }
}
