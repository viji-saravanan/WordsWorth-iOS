import Foundation

enum GameStatsFactory {
    static func fromRecords(wordLength: Int, records: [GameRecord]) -> GameStats {
        let filtered = records
            .filter { $0.wordLength == wordLength }
            .sorted { $0.playedAtEpochMillis > $1.playedAtEpochMillis }

        let totalGames = filtered.count
        let wins = filtered.filter { $0.won }.count
        let losses = totalGames - wins
        let winRate = totalGames == 0 ? 0.0 : Double(wins) / Double(totalGames)
        let lossRate = totalGames == 0 ? 0.0 : Double(losses) / Double(totalGames)
        let averageGuesses: Double = {
            let winGames = filtered.filter { $0.won }
            guard !winGames.isEmpty else { return 0.0 }
            let totalGuesses = winGames.reduce(0) { $0 + $1.guessCount }
            return Double(totalGuesses) / Double(winGames.count)
        }()

        var distribution = [Int: Int]()
        for attempt in 1...GameRules.maxAttempts {
            distribution[attempt] = 0
        }
        filtered.filter { $0.won }.forEach { record in
            let key = min(max(record.guessCount, 1), GameRules.maxAttempts)
            distribution[key, default: 0] += 1
        }
        let misses = filtered.filter { !$0.won }.count

        var bestStreak = 0
        var currentStreak = 0
        for record in filtered {
            if record.won {
                currentStreak += 1
                bestStreak = max(bestStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }

        return GameStats(
            wordLength: wordLength,
            totalGames: totalGames,
            wins: wins,
            losses: losses,
            winRate: winRate,
            lossRate: lossRate,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            averageGuesses: averageGuesses,
            guessDistribution: distribution,
            misses: misses,
            recentGames: Array(filtered.prefix(10))
        )
    }
}

struct GameResult: Codable {
    let word: String
    let wordLength: Int
    let guessCount: Int
    let won: Bool
    let playedAtEpochMillis: Int64

    init(word: String, wordLength: Int, guessCount: Int, won: Bool, playedAtEpochMillis: Int64 = Date.epochMillis) {
        self.word = word
        self.wordLength = wordLength
        self.guessCount = guessCount
        self.won = won
        self.playedAtEpochMillis = playedAtEpochMillis
    }
}

struct GameRecord: Identifiable, Codable, Equatable {
    let id: String
    let word: String
    let wordLength: Int
    let guessCount: Int
    let won: Bool
    let playedAtEpochMillis: Int64
    let createdByCloud: Bool

    init(
        id: String = UUID().uuidString,
        word: String,
        wordLength: Int,
        guessCount: Int,
        won: Bool,
        playedAtEpochMillis: Int64,
        createdByCloud: Bool = false
    ) {
        self.id = id
        self.word = word
        self.wordLength = wordLength
        self.guessCount = guessCount
        self.won = won
        self.playedAtEpochMillis = playedAtEpochMillis
        self.createdByCloud = createdByCloud
    }
}

struct GameStats: Equatable {
    let wordLength: Int
    let totalGames: Int
    let wins: Int
    let losses: Int
    let winRate: Double
    let lossRate: Double
    let currentStreak: Int
    let bestStreak: Int
    let averageGuesses: Double
    let guessDistribution: [Int: Int]
    let misses: Int
    let recentGames: [GameRecord]

    static let empty = GameStats(
        wordLength: WordLengthOption.defaultOption.letters,
        totalGames: 0,
        wins: 0,
        losses: 0,
        winRate: 0.0,
        lossRate: 0.0,
        currentStreak: 0,
        bestStreak: 0,
        averageGuesses: 0.0,
        guessDistribution: (1...GameRules.maxAttempts).reduce(into: [:]) { $0[$1] = 0 },
        misses: 0,
        recentGames: []
    )
}

private extension Date {
    static var epochMillis: Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
