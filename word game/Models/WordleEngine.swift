import Foundation

enum LetterStatus: String, Codable {
    case correct
    case present
    case absent
    case empty
}

struct LetterFeedback: Identifiable, Equatable {
    let id: UUID
    let letter: Character
    let status: LetterStatus

    init(letter: Character, status: LetterStatus, id: UUID = UUID()) {
        self.letter = letter
        self.status = status
        self.id = id
    }
}

struct GuessEvaluation: Identifiable, Equatable {
    let id: UUID
    let guess: String
    let feedback: [LetterFeedback]

    init(guess: String, feedback: [LetterFeedback], id: UUID = UUID()) {
        self.guess = guess
        self.feedback = feedback
        self.id = id
    }
}

enum WordleEngine {
    static func evaluate(guess: String, answer: String) -> GuessEvaluation {
        let target = Array(answer.uppercased())
        let attempt = Array(guess.uppercased())
        var statuses = Array(repeating: LetterStatus.absent, count: attempt.count)
        var counts = Array(repeating: 0, count: 26)

        for char in target {
            let idx = char.toAlphabetIndex()
            if idx >= 0 { counts[idx] += 1 }
        }

        for index in attempt.indices {
            guard index < target.count else { continue }
            let guessChar = attempt[index]
            if guessChar == target[index] {
                statuses[index] = .correct
                let idx = guessChar.toAlphabetIndex()
                if idx >= 0 { counts[idx] -= 1 }
            }
        }

        for index in attempt.indices {
            if statuses[index] == .correct { continue }
            let guessChar = attempt[index]
            let idx = guessChar.toAlphabetIndex()
            if idx >= 0, counts[idx] > 0 {
                statuses[index] = .present
                counts[idx] -= 1
            } else {
                statuses[index] = .absent
            }
        }

        let feedback = attempt.indices.map { index in
            LetterFeedback(letter: attempt[index], status: statuses[index])
        }

        return GuessEvaluation(guess: String(attempt), feedback: feedback)
    }

    static func mergeStatus(existing: LetterStatus?, incoming: LetterStatus) -> LetterStatus {
        guard let existing else { return incoming }
        if incoming == .correct { return .correct }
        if incoming == .present, existing == .absent { return .present }
        return existing
    }
}

private extension Character {
    func toAlphabetIndex() -> Int {
        guard let scalar = String(self).unicodeScalars.first else { return -1 }
        let value = Int(scalar.value)
        let aValue = Int(UnicodeScalar("A").value)
        let zValue = Int(UnicodeScalar("Z").value)
        if value >= aValue && value <= zValue {
            return value - aValue
        }
        return -1
    }
}
