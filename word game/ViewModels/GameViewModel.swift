import Combine
import Foundation

struct StatsUiState: Equatable {
    var isLoading: Bool
    var stats: GameStats?
    var error: String?
}

struct GameUiState: Equatable {
    var option: WordLengthOption
    var guesses: [GuessEvaluation]
    var currentGuess: String
    var keyboard: [Character: LetterStatus]
    var isComplete: Bool
    var isWin: Bool
    var revealAnswer: Bool
    var answerToReveal: String?
    var wordDetails: WordDetails?
    var showStats: Bool
    var statsState: StatsUiState
    var userMessage: String?
    var isCloudEnabled: Bool
    var isLoadingWord: Bool
}

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var state: GameUiState

    private let wordService: RemoteWordService
    private let statsRepository: StatsRepository
    private var answer: String = ""
    private var currentDetails: WordDetails?

    init(wordService: RemoteWordService, statsRepository: StatsRepository) {
        self.wordService = wordService
        self.statsRepository = statsRepository
        self.state = GameUiState(
            option: .defaultOption,
            guesses: [],
            currentGuess: "",
            keyboard: [:],
            isComplete: false,
            isWin: false,
            revealAnswer: false,
            answerToReveal: nil,
            wordDetails: nil,
            showStats: false,
            statsState: StatsUiState(isLoading: true, stats: nil, error: nil),
            userMessage: nil,
            isCloudEnabled: statsRepository.isCloudEnabled,
            isLoadingWord: false
        )
        startNewGame(option: .defaultOption, shouldReloadStats: true)
    }

    func onLetterInput(_ letter: Character) {
        let current = state
        guard !current.isComplete, !current.isLoadingWord else { return }
        guard letter.isAlphabetic else { return }
        guard current.currentGuess.count < current.option.letters else { return }
        state.currentGuess.append(contentsOf: String(letter).uppercased())
        state.userMessage = nil
    }

    func onBackspace() {
        guard !state.currentGuess.isEmpty, !state.isComplete, !state.isLoadingWord else { return }
        state.currentGuess.removeLast()
    }

    func onSubmitGuess() {
        let current = state
        guard !current.isComplete, !current.isLoadingWord else { return }

        let guess = current.currentGuess.uppercased()
        if guess.count != current.option.letters {
            setUserMessage("Need \(current.option.letters) letters")
            return
        }
        if !guess.isAlphabetic {
            setUserMessage("Use letters only")
            return
        }

        let evaluation = WordleEngine.evaluate(guess: guess, answer: answer)
        var updatedGuesses = current.guesses
        updatedGuesses.append(evaluation)
        updatedGuesses = Array(updatedGuesses.suffix(GameRules.maxAttempts))

        var updatedKeyboard = current.keyboard
        for feedback in evaluation.feedback {
            let existing = updatedKeyboard[feedback.letter]
            updatedKeyboard[feedback.letter] = WordleEngine.mergeStatus(existing: existing, incoming: feedback.status)
        }

        let isWin = guess == answer
        let isComplete = isWin || updatedGuesses.count >= GameRules.maxAttempts
        let revealAnswer = isComplete && !isWin

        state.guesses = updatedGuesses
        state.currentGuess = ""
        state.keyboard = updatedKeyboard
        state.isComplete = isComplete
        state.isWin = isWin
        state.revealAnswer = revealAnswer
        if isComplete {
            state.answerToReveal = answer
            state.wordDetails = currentDetails
            state.userMessage = isWin ? "Great job!" : nil
        }

        if isComplete {
            recordResult(guessCount: updatedGuesses.count, won: isWin)
        }
    }

    func onModeSelected(_ option: WordLengthOption) {
        guard state.option != option else { return }
        startNewGame(option: option, shouldReloadStats: true)
    }

    func onNewGameRequested() {
        startNewGame(option: state.option, shouldReloadStats: false)
    }

    func onStatsVisibilityChange(_ show: Bool) {
        state.showStats = show
        if show {
            refreshStats(force: false)
        }
    }

    func consumeUserMessage() {
        state.userMessage = nil
    }

    func refreshStats(force: Bool = true, option: WordLengthOption? = nil) {
        if !force, state.statsState.stats != nil { return }
        state.statsState = StatsUiState(isLoading: true, stats: state.statsState.stats, error: nil)
        Task {
            do {
                let length = option?.letters ?? state.option.letters
                let stats = try await statsRepository.loadStats(wordLength: length)
                state.statsState = StatsUiState(isLoading: false, stats: stats, error: nil)
            } catch {
                state.statsState = StatsUiState(
                    isLoading: false,
                    stats: state.statsState.stats,
                    error: error.localizedDescription
                )
                setUserMessage("Unable to reach stats. Working offline.")
            }
        }
    }

    private func setUserMessage(_ message: String) {
        state.userMessage = message
    }

    private func startNewGame(option: WordLengthOption, shouldReloadStats: Bool) {
        answer = ""
        currentDetails = nil
        state.option = option
        state.guesses = []
        state.currentGuess = ""
        state.keyboard = [:]
        state.isComplete = false
        state.isWin = false
        state.revealAnswer = false
        state.answerToReveal = nil
        state.showStats = false
        if shouldReloadStats {
            state.statsState = StatsUiState(isLoading: true, stats: nil, error: nil)
        }
        state.userMessage = nil
        state.isLoadingWord = true
        state.wordDetails = nil

        Task {
            await prepareNewGame(option: option, shouldReloadStats: shouldReloadStats)
        }
    }

    private func prepareNewGame(option: WordLengthOption, shouldReloadStats: Bool) async {
        if shouldReloadStats {
            refreshStats(force: true, option: option)
        }

        let challenge = try? await wordService.fetchWordChallenge(option: option)
        guard let challenge else {
            state.isLoadingWord = false
            setUserMessage("Unable to fetch a word. Try again.")
            return
        }
        answer = challenge.word.uppercased()
        currentDetails = challenge.details
        state.isLoadingWord = false
    }

    private func recordResult(guessCount: Int, won: Bool) {
        let result = GameResult(
            word: answer,
            wordLength: state.option.letters,
            guessCount: guessCount,
            won: won
        )
        Task {
            await statsRepository.recordGame(result)
            refreshStats(force: true)
        }
    }
}
