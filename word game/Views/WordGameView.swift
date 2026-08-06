import SwiftUI

struct WordGamePlayView: View {
    let state: GameUiState
    let onLetter: (Character) -> Void
    let onDelete: () -> Void
    let onSubmit: () -> Void
    let onModeSelect: (WordLengthOption) -> Void
    let onNewGame: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose your word length")
                    .font(.headline.weight(.semibold))
                Text("You have \(GameRules.maxAttempts) attempts to guess the word.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                WordLengthSelector(selected: state.option, enabled: !state.isLoadingWord, onSelect: onModeSelect)
            }
            if state.isLoadingWord {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Fetching a new word and meaning...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            if horizontalSizeClass == .regular {
                HStack(alignment: .top, spacing: 24) {
                    VStack(spacing: 12) {
                        GameBoard(state: state)
                        if state.isComplete {
                            CompletionSection(state: state, onNewGame: onNewGame)
                        }
                    }
                    GameKeyboard(
                        keyboardState: state.keyboard,
                        onLetter: onLetter,
                        onDelete: onDelete,
                        onSubmit: onSubmit,
                        enabled: !state.isComplete && !state.isLoadingWord
                    )
                    .frame(maxWidth: 420)
                }
            } else {
                VStack(spacing: 16) {
                    GameBoard(state: state)
                    if state.isComplete {
                        CompletionSection(state: state, onNewGame: onNewGame)
                    }
                    GameKeyboard(
                        keyboardState: state.keyboard,
                        onLetter: onLetter,
                        onDelete: onDelete,
                        onSubmit: onSubmit,
                        enabled: !state.isComplete && !state.isLoadingWord
                    )
                }
            }
        }
    }
}

private struct WordLengthSelector: View {
    let selected: WordLengthOption
    let enabled: Bool
    let onSelect: (WordLengthOption) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(WordLengthOption.allCases) { option in
                let isSelected = option == selected
                Button(action: { onSelect(option) }) {
                    Text(option.label)
                        .font(.caption.weight(isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isSelected ?
                                      LinearGradient(colors: [ThemeColors.accentBlue, ThemeColors.accentMint], startPoint: .topLeading, endPoint: .bottomTrailing)
                                      : LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
            }
        }
    }
}

private struct GameBoard: View {
    let state: GameUiState

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<GameRules.maxAttempts, id: \.self) { row in
                let feedback = feedbackForRow(row)
                HStack(spacing: 8) {
                    ForEach(feedback) { letter in
                        LetterTile(feedback: letter)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .frame(maxWidth: 420)
    }

    private func feedbackForRow(_ row: Int) -> [LetterFeedback] {
        if state.guesses.count > row {
            return state.guesses[row].feedback
        }
        if state.guesses.count == row {
            return buildPendingFeedback(guess: state.currentGuess, length: state.option.letters)
        }
        return buildPendingFeedback(guess: "", length: state.option.letters)
    }

    private func buildPendingFeedback(guess: String, length: Int) -> [LetterFeedback] {
        let upper = guess.uppercased()
        return (0..<length).map { index in
            let letter = upper.dropFirst(index).first ?? " "
            return LetterFeedback(letter: letter, status: .empty)
        }
    }
}

private struct LetterTile: View {
    let feedback: LetterFeedback
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let background = tileBackground(for: feedback.status)
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(background)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor(for: feedback.status), lineWidth: 1)
            )
            .overlay(
                Text(feedback.letter == " " ? "" : String(feedback.letter))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(textColor(for: feedback.status))
            )
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 4)
    }

    private func tileBackground(for status: LetterStatus) -> LinearGradient {
        switch status {
        case .correct:
            return LinearGradient(colors: [ThemeColors.greenCorrect.opacity(0.95), ThemeColors.greenCorrect.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .present:
            return LinearGradient(colors: [ThemeColors.yellowPresent.opacity(0.95), ThemeColors.yellowPresent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .absent:
            return LinearGradient(colors: [ThemeColors.grayAbsent.opacity(0.95), ThemeColors.grayAbsent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .empty:
            let top = colorScheme == .dark ? Color.white.opacity(0.22) : Color.white.opacity(0.8)
            let bottom = colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.6)
            return LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func borderColor(for status: LetterStatus) -> Color {
        if status == .empty {
            return colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.12)
        }
        return Color.white.opacity(0.25)
    }

    private func textColor(for status: LetterStatus) -> Color {
        status == .empty ? .primary : .white
    }
}

private struct CompletionSection: View {
    let state: GameUiState
    let onNewGame: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            CompletionCard(
                isWin: state.isWin,
                answer: state.answerToReveal,
                guessCount: state.guesses.count,
                onNewGame: onNewGame
            )
            if let answer = state.answerToReveal {
                WordMeaningCard(answer: answer, details: state.wordDetails)
            }
        }
    }
}

private struct CompletionCard: View {
    let isWin: Bool
    let answer: String?
    let guessCount: Int
    let onNewGame: () -> Void

    var body: some View {
        GlassSurface(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(isWin ? "You solved it!" : "Better luck next time")
                    .font(.headline.weight(.semibold))
                if isWin {
                    Text("Solved in \(guessCount) guesses.")
                        .font(.subheadline)
                } else if let answer {
                    Text("The word was \(answer).")
                        .font(.subheadline)
                } else {
                    Text("All \(GameRules.maxAttempts) attempts used.")
                        .font(.subheadline)
                }
                Button(action: onNewGame) {
                    Text("Play another round")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(colors: [ThemeColors.accentBlue, ThemeColors.accentMint], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct WordMeaningCard: View {
    let answer: String
    let details: WordDetails?

    var body: some View {
        GlassSurface(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(answer)
                    .font(.title3.weight(.bold))
                if !familyLabel.isEmpty {
                    Text("Word families: \(familyLabel)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if meanings.isEmpty {
                    Text("We couldn't find a reliable definition for this word.")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ViewThatFits(in: .vertical) {
                        MeaningList(meanings: meanings)
                        ScrollView {
                            MeaningList(meanings: meanings)
                        }
                        .scrollIndicators(.hidden)
                        .frame(maxHeight: 190)
                    }
                }
            }
        }
    }

    private var familyLabel: String {
        var seen: [String] = []
        for meaning in meanings {
            let part = meaning.partOfSpeech?.capitalized ?? ""
            guard !part.isEmpty, !seen.contains(part) else { continue }
            seen.append(part)
        }
        return seen.joined(separator: " · ")
    }

    private var meanings: [WordMeaning] {
        details?.meanings ?? []
    }
}

private struct MeaningList: View {
    let meanings: [WordMeaning]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(meanings.indices, id: \.self) { meaningIndex in
                let meaning = meanings[meaningIndex]
                VStack(alignment: .leading, spacing: 6) {
                    if let part = meaning.partOfSpeech, !part.isEmpty {
                        Text(part.capitalized)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    ForEach(meaning.definitions.indices, id: \.self) { definitionIndex in
                        let definition = meaning.definitions[definitionIndex]
                        Text("\(definitionIndex + 1). \(definition.definition)")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        if let example = definition.example, !example.isEmpty {
                            Text("Example: \(example)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

private enum KeySpec {
    case letter(Character)
    case enter
    case delete
}

private struct GameKeyboard: View {
    let keyboardState: [Character: LetterStatus]
    let onLetter: (Character) -> Void
    let onDelete: () -> Void
    let onSubmit: () -> Void
    let enabled: Bool

    private let firstRow = Array("QWERTYUIOP")
    private let secondRow = Array("ASDFGHJKL")
    private let thirdRow = Array("ZXCVBNM")

    var body: some View {
        let rows: [[KeySpec]] = [
            firstRow.map { .letter($0) },
            secondRow.map { .letter($0) },
            [KeySpec.enter] + thirdRow.map { .letter($0) } + [KeySpec.delete]
        ]
        VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    ForEach(rows[rowIndex].indices, id: \.self) { index in
                        keyButton(for: rows[rowIndex][index])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(for key: KeySpec) -> some View {
        switch key {
        case .letter(let letter):
            let colors = keyColors(for: keyboardState[letter])
            KeyButton(
                label: String(letter),
                background: colors.background,
                foreground: colors.foreground,
                icon: nil,
                action: { onLetter(letter) },
                enabled: enabled
            )
            .frame(maxWidth: .infinity)
        case .enter:
            KeyButton(
                label: "",
                background: ThemeColors.accentBlue,
                foreground: .white,
                icon: Image(systemName: "checkmark"),
                action: onSubmit,
                enabled: enabled
            )
            .frame(maxWidth: .infinity)
        case .delete:
            KeyButton(
                label: "",
                background: ThemeColors.accentBlue,
                foreground: .white,
                icon: Image(systemName: "delete.left"),
                action: onDelete,
                enabled: enabled
            )
            .frame(maxWidth: .infinity)
        }
    }

    private func keyColors(for status: LetterStatus?) -> (background: Color, foreground: Color) {
        switch status {
        case .correct?:
            return (ThemeColors.greenCorrect, .white)
        case .present?:
            return (ThemeColors.yellowPresent, .black)
        case .absent?:
            return (ThemeColors.grayAbsent, .white)
        case .empty, nil:
            return (Color.white.opacity(0.25), .primary)
        }
    }
}

private struct KeyButton: View {
    let label: String
    let background: Color
    let foreground: Color
    let icon: Image?
    let action: () -> Void
    let enabled: Bool

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [background.opacity(0.95), background.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                if let icon {
                    icon
                        .foregroundColor(foreground)
                } else {
                    Text(label)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(foreground)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(height: 50)
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
    }
}
