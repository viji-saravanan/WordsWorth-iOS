import Foundation

actor LocalStatsRepository: StatsRepository {
    nonisolated let isCloudEnabled = false
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func recordGame(_ result: GameResult) async {
        var records = loadRecords()
        records.append(
            GameRecord(
                word: result.word,
                wordLength: result.wordLength,
                guessCount: result.guessCount,
                won: result.won,
                playedAtEpochMillis: result.playedAtEpochMillis,
                createdByCloud: false
            )
        )
        saveRecords(records)
    }

    func loadStats(wordLength: Int) async throws -> GameStats {
        let records = loadRecords()
        return GameStatsFactory.fromRecords(wordLength: wordLength, records: records)
    }

    private func loadRecords() -> [GameRecord] {
        guard let data = defaults.data(forKey: Keys.records) else {
            return []
        }
        return (try? decoder.decode([GameRecord].self, from: data)) ?? []
    }

    private func saveRecords(_ records: [GameRecord]) {
        if let data = try? encoder.encode(records) {
            defaults.set(data, forKey: Keys.records)
        }
    }

    private enum Keys {
        static let records = "wordgame_game_records"
    }
}
