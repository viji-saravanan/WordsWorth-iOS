import Combine
import Foundation

enum DashboardTab: String, CaseIterable, Identifiable {
    case dictionary
    case daily
    case play
    case thesaurus
    case stats

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dictionary: return "Dictionary"
        case .daily: return "Daily"
        case .play: return "Play"
        case .thesaurus: return "Thesaurus"
        case .stats: return "Stats"
        }
    }

    var iconName: String {
        switch self {
        case .dictionary: return "magnifyingglass"
        case .daily: return "book"
        case .play: return "play.circle.fill"
        case .thesaurus: return "text.book.closed"
        case .stats: return "chart.bar"
        }
    }

    var isPrimary: Bool {
        self == .play
    }
}

struct DashboardUiState: Equatable {
    var selectedTab: DashboardTab
    var dailyWords: [WordInsight]
    var isDailyLoading: Bool
    var dailyError: String?
    var dictionaryQuery: String
    var dictionaryResult: WordInsight?
    var isDictionaryLoading: Bool
    var dictionaryError: String?
    var thesaurusQuery: String
    var thesaurusResult: ThesaurusResult?
    var isThesaurusLoading: Bool
    var thesaurusError: String?
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var state: DashboardUiState

    private let wordService: RemoteWordService
    private let dailyWordsService: DailyWordsService

    init(wordService: RemoteWordService, dailyWordsService: DailyWordsService) {
        self.wordService = wordService
        self.dailyWordsService = dailyWordsService
        self.state = DashboardUiState(
            selectedTab: .play,
            dailyWords: [],
            isDailyLoading: false,
            dailyError: nil,
            dictionaryQuery: "",
            dictionaryResult: nil,
            isDictionaryLoading: false,
            dictionaryError: nil,
            thesaurusQuery: "",
            thesaurusResult: nil,
            isThesaurusLoading: false,
            thesaurusError: nil
        )
        refreshDailyWords(force: false)
    }

    func selectTab(_ tab: DashboardTab) {
        state.selectedTab = tab
    }

    func updateDictionaryQuery(_ value: String) {
        state.dictionaryQuery = value
        state.dictionaryError = nil
    }

    func updateThesaurusQuery(_ value: String) {
        state.thesaurusQuery = value
        state.thesaurusError = nil
    }

    func refreshDailyWords(force: Bool) {
        if !force, !state.dailyWords.isEmpty { return }
        state.isDailyLoading = true
        state.dailyError = nil
        Task {
            let words = await dailyWordsService.getDailyWords()
            if words.isEmpty {
                state.isDailyLoading = false
                state.dailyError = "Unable to load today's words."
                state.dailyWords = []
            } else {
                state.isDailyLoading = false
                state.dailyError = nil
                state.dailyWords = words
            }
        }
    }

    func searchDictionary() {
        let query = state.dictionaryQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state.dictionaryError = "Enter a word to search."
            return
        }
        state.isDictionaryLoading = true
        state.dictionaryError = nil
        Task {
            let result = await wordService.fetchWordInsight(word: query)
            if let result {
                state.isDictionaryLoading = false
                state.dictionaryResult = result
                state.dictionaryError = nil
            } else {
                state.isDictionaryLoading = false
                state.dictionaryResult = nil
                state.dictionaryError = "No definition found."
            }
        }
    }

    func searchThesaurus() {
        let query = state.thesaurusQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state.thesaurusError = "Enter a word to explore synonyms."
            return
        }
        state.isThesaurusLoading = true
        state.thesaurusError = nil
        Task {
            let insight = await wordService.fetchWordInsight(word: query)
            let meanings = insight?.meanings ?? []
            let hasSynonyms = meanings.contains { meaning in
                meaning.definitions.contains { !$0.synonyms.isEmpty }
            }
            var fallbackSynonyms: [String] = []
            if !hasSynonyms {
                fallbackSynonyms = await wordService.fetchSynonyms(word: query, max: 12)
            }

            if meanings.isEmpty, fallbackSynonyms.isEmpty {
                state.isThesaurusLoading = false
                state.thesaurusResult = nil
                state.thesaurusError = "No thesaurus entries found."
                return
            }

            state.isThesaurusLoading = false
            state.thesaurusResult = ThesaurusResult(
                word: insight?.word ?? query,
                meanings: meanings,
                fallbackSynonyms: fallbackSynonyms
            )
            state.thesaurusError = nil
        }
    }
}
