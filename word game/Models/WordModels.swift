import Foundation

struct WordDetails: Codable, Equatable {
    let meanings: [WordMeaning]
}

struct WordChallenge: Codable, Equatable {
    let word: String
    let details: WordDetails?
}
