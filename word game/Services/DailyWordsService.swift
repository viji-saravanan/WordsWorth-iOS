import Foundation

actor DailyWordsService {
    private let remote: RemoteWordService
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(remote: RemoteWordService, defaults: UserDefaults = .standard) {
        self.remote = remote
        self.defaults = defaults
    }

    func getDailyWords(count: Int = 5) async -> [WordInsight] {
        let today = todayStamp()
        if let cachedDate = defaults.string(forKey: Keys.date),
           let cachedPayload = defaults.data(forKey: Keys.payload),
           cachedDate == today,
           let cached = try? decoder.decode([WordInsight].self, from: cachedPayload),
           !cached.isEmpty {
            return cached
        }

        let words = await remote.fetchRandomWords(count: count)
        if words.isEmpty { return [] }

        var seen = Set<String>()
        let uniqueWords = words.map { $0.lowercased() }.filter { seen.insert($0).inserted }
        var insights: [WordInsight] = []
        await withTaskGroup(of: WordInsight?.self) { group in
            for word in uniqueWords {
                group.addTask {
                    await self.remote.fetchWordInsight(word: word) ?? WordInsight(word: word)
                }
            }
            for await insight in group {
                if let insight {
                    insights.append(insight)
                }
            }
        }

        let trimmed = Array(insights.prefix(count))
        if let payload = try? encoder.encode(trimmed) {
            defaults.set(today, forKey: Keys.date)
            defaults.set(payload, forKey: Keys.payload)
        }

        return trimmed
    }

    private func todayStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    private enum Keys {
        static let date = "daily_words_date"
        static let payload = "daily_words_payload"
    }
}
