import Foundation

protocol StatsRepository: AnyObject {
    var isCloudEnabled: Bool { get }
    func recordGame(_ result: GameResult) async
    func loadStats(wordLength: Int) async throws -> GameStats
}
