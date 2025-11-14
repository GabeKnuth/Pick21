import Foundation
import Combine

@MainActor
final class GameState: ObservableObject {
    // MARK: - Published State
    @Published var columns: [Column] = Array(repeating: Column(), count: 5)
    @Published var currentCard: Card?
    @Published var round: Int = 1 // 1...3
    @Published var totalScore: Int = 0
    @Published var roundScores: [Int] = [0, 0, 0]
    @Published var roundEndReason: RoundEndReason = .none
    @Published var phase: GamePhase = .inRound
    @Published var timerValue: Int = 280
    @Published var passAvailable: Bool = true
    @Published var isNewHighScore: Bool = false
    @Published var highScores: ScoreTable = HighScoresStorage.load()

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

    // MARK: - Init
    init() {
        startNewGame()
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

        // Transition phase
        if round < 3 {
            phase = .betweenRounds
        } else {
            phase = .gameOver
            // Save to high scores
            let isTop = highScores.insert(score: totalScore)
            isNewHighScore = isTop
            HighScoresStorage.save(highScores)
        }
    }

    func nextRound() {
        guard phase == .betweenRounds else { return }
        round += 1
        startRound()
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
