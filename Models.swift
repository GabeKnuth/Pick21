import Foundation

enum Suit: String, CaseIterable, Codable {
    case hearts = "♥︎"
    case diamonds = "♦︎"
    case clubs = "♣︎"
    case spades = "♠︎"
}

enum Rank: String, CaseIterable, Codable {
    case ace = "A"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case ten = "10"
    case jack = "J"
    case queen = "Q"
    case king = "K"

    var baseValue: Int {
        switch self {
        case .ace: return 1
        case .two: return 2
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case .seven: return 7
        case .eight: return 8
        case .nine: return 9
        case .ten, .jack, .queen, .king: return 10
        }
    }
}

struct Card: Identifiable, Codable, Equatable {
    let id = UUID()
    let rank: Rank
    let suit: Suit

    var display: String {
        "\(rank.rawValue)\(suit.rawValue)"
    }
}

struct Column: Identifiable, Codable {
    let id = UUID()
    var cards: [Card] = []
    var isLocked: Bool = false
    var isFiveCardCharlie: Bool = false

    // Blackjack-like tally with ace upgrades
    var total: Int {
        var sum = cards.reduce(0) { $0 + $1.rank.baseValue }
        var aceCount = cards.filter { $0.rank == .ace }.count
        while aceCount > 0 && sum + 10 <= 21 {
            sum += 10
            aceCount -= 1
        }
        return sum
    }

    // SOFT means: at least one Ace is currently counted as 11 in the computed total
    // and the hand has at least two cards (a lone Ace should not be called soft).
    var isSoft: Bool {
        guard cards.count >= 2 else { return false }
        let base = cards.reduce(0) { $0 + $1.rank.baseValue }
        let hasAce = cards.contains(where: { $0.rank == .ace })
        // If adding +10 to the base sum (treating one Ace as 11) does not bust,
        // then the computed total is using an Ace as 11, i.e., it's soft.
        return hasAce && base + 10 <= 21
    }

    var busted: Bool {
        total > 21
    }

    var effectiveTotal: Int {
        if isFiveCardCharlie { return 21 }
        return min(total, 21)
    }

    mutating func add(_ card: Card) {
        guard !isLocked else { return }
        cards.append(card)
        updateLockAndCharlie()
    }

    mutating func updateLockAndCharlie() {
        // Lock for five-card Charlie (5 cards and total ≤ 21)
        if cards.count >= 5 && total <= 21 {
            isFiveCardCharlie = true
            isLocked = true
            return
        }

        // Lock only on HARD 21 (not soft)
        if total == 21 && !isSoft {
            isLocked = true
        } else if isLocked && total != 21 && !isFiveCardCharlie {
            // Safety: if state ever becomes inconsistent, unlock
            isLocked = false
        }
    }

    mutating func reset() {
        cards.removeAll()
        isLocked = false
        isFiveCardCharlie = false
    }
}

struct HighScoreEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let score: Int
    let date: Date

    init(score: Int, date: Date) {
        self.id = UUID()
        self.score = score
        self.date = date
    }
}

struct ScoreTable: Codable {
    var entries: [HighScoreEntry] = []
    let maxEntries: Int = 10

    mutating func insert(score: Int, date: Date = Date()) -> Bool {
        let entry = HighScoreEntry(score: score, date: date)
        entries.append(entry)
        entries.sort { $0.score > $1.score }
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        return entries.first?.id == entry.id
    }
}

enum RoundEndReason: String, Codable {
    case none
    case bust
    case tookScore
    case perfectBoard
    case timerExpired
}

enum GamePhase: Codable, Equatable {
    case preGame
    case inRound
    case betweenRounds
    case gameOver
}

struct RoundResult: Identifiable, Codable {
    let id = UUID()
    let roundIndex: Int
    let score: Int
    let endReason: RoundEndReason
}

