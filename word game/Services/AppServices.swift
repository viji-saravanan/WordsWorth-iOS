import Foundation

final class AppServices {
    static let shared = AppServices()

    let wordService: RemoteWordService
    let dailyWordsService: DailyWordsService
    let statsRepository: LocalStatsRepository

    private init() {
        let wordService = RemoteWordService()
        self.wordService = wordService
        self.dailyWordsService = DailyWordsService(remote: wordService)
        self.statsRepository = LocalStatsRepository()
    }
}
