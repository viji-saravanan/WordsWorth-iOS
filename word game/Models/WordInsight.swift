import Foundation

struct WordDefinition: Codable, Equatable, Hashable {
    let definition: String
    let example: String?
    let synonyms: [String]
    let antonyms: [String]
}

struct WordMeaning: Codable, Equatable, Hashable {
    let partOfSpeech: String?
    let definitions: [WordDefinition]
}

struct WordInsight: Codable, Identifiable, Equatable {
    var id: String { word }
    let word: String
    let meanings: [WordMeaning]

    init(word: String, meanings: [WordMeaning] = []) {
        self.word = word
        self.meanings = meanings
    }
}
