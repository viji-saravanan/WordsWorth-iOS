import Foundation

extension Character {
    var isAlphabetic: Bool {
        unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
    }
}

extension String {
    var isAlphabetic: Bool {
        allSatisfy { $0.isAlphabetic }
    }
}
