import Foundation

struct ThesaurusResult: Equatable {
    let word: String
    let meanings: [WordMeaning]
    let fallbackSynonyms: [String]
}
