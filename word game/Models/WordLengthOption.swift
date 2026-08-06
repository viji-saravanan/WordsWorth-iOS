import Foundation

enum WordLengthOption: Int, CaseIterable, Identifiable, Codable {
    case four = 4
    case five = 5

    var id: Int { rawValue }
    var letters: Int { rawValue }

    var label: String {
        switch self {
        case .four: return "4 Letters"
        case .five: return "5 Letters"
        }
    }

    static func fromLetters(_ count: Int) -> WordLengthOption {
        WordLengthOption(rawValue: count) ?? .five
    }

    static let defaultOption: WordLengthOption = .five
}
