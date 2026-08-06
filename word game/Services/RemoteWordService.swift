import Foundation

actor RemoteWordService {
    enum ServiceError: Error {
        case missingWord
    }

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func fetchWordChallenge(option: WordLengthOption) async throws -> WordChallenge {
        let words = await fetchRandomWords(count: 1, length: option.letters)
        guard let word = words.first else { throw ServiceError.missingWord }
        let details = await fetchWordDetails(word: word)
        return WordChallenge(word: word, details: details)
    }

    func fetchWordDetails(word: String) async -> WordDetails? {
        let lower = word.lowercased()
        guard let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(lower)") else {
            return nil
        }
        guard let data = await fetchData(url) else { return nil }
        guard let entries = try? decoder.decode([DictionaryEntry].self, from: data) else { return nil }
        let meanings = mergeMeanings(entries.flatMap { buildMeanings(from: $0) })
        guard !meanings.isEmpty else { return nil }
        return WordDetails(meanings: meanings)
    }

    func fetchWordInsight(word: String) async -> WordInsight? {
        let lower = word.lowercased()
        guard let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(lower)") else {
            return nil
        }
        guard let data = await fetchData(url) else { return nil }
        guard let entries = try? decoder.decode([DictionaryEntry].self, from: data) else { return nil }
        guard let entry = entries.first else { return nil }
        let meanings = mergeMeanings(entries.flatMap { buildMeanings(from: $0) })
        guard !meanings.isEmpty else { return nil }
        return WordInsight(
            word: entry.word?.trimmed ?? lower,
            meanings: meanings
        )
    }

    func fetchSynonyms(word: String, max: Int = 12) async -> [String] {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? word
        guard let url = URL(string: "https://api.datamuse.com/words?rel_syn=\(encoded)&max=\(max)") else {
            return []
        }
        guard let data = await fetchData(url) else { return [] }
        guard let results = try? decoder.decode([DatamuseEntry].self, from: data) else { return [] }
        return results.compactMap { $0.word?.trimmed }.filter { !$0.isEmpty }.uniquePrefix(max)
    }

    func fetchRandomWords(count: Int, length: Int? = nil) async -> [String] {
        let primary = await fetchRandomWords(from: buildRandomWordUrl(count: count, length: length))
        if !primary.isEmpty { return primary }
        let fallback = await fetchRandomWords(from: buildFallbackRandomWordUrl(count: count, length: length))
        return fallback
    }

    private func fetchRandomWords(from url: URL?) async -> [String] {
        guard let url else { return [] }
        guard let data = await fetchData(url) else { return [] }
        guard let words = try? decoder.decode([String].self, from: data) else { return [] }
        return words
            .map { $0.trimmed.uppercased() }
            .filter { !$0.isEmpty }
            .uniquePrefix(count: words.count)
    }

    private func fetchData(_ url: URL) async -> Data? {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    private func buildRandomWordUrl(count: Int, length: Int?) -> URL? {
        var components = URLComponents(string: "https://random-word-api.vercel.app/api")
        var items = [URLQueryItem(name: "words", value: String(count))]
        if let length {
            items.append(URLQueryItem(name: "length", value: String(length)))
        }
        components?.queryItems = items
        return components?.url
    }

    private func buildFallbackRandomWordUrl(count: Int, length: Int?) -> URL? {
        var components = URLComponents(string: "https://random-word-api.herokuapp.com/word")
        var items = [URLQueryItem(name: "number", value: String(count))]
        if let length {
            items.append(URLQueryItem(name: "length", value: String(length)))
        }
        components?.queryItems = items
        return components?.url
    }

    private func collectWords(_ wordLists: [String]?...) -> [String] {
        wordLists
            .compactMap { $0 }
            .flatMap { $0 }
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
            .uniquePrefix(count: 24)
    }

    private func buildMeanings(from entry: DictionaryEntry) -> [WordMeaning] {
        entry.meanings.compactMap { meaning in
            let part = meaning.partOfSpeech?.trimmed
            let definitions: [WordDefinition] = meaning.definitions.compactMap { definition -> WordDefinition? in
                guard let text = definition.definition?.trimmed, !text.isEmpty else { return nil }
                let definitionSynonyms = collectWords(definition.synonyms)
                let definitionAntonyms = collectWords(definition.antonyms)
                let synonyms = definitionSynonyms.isEmpty ? collectWords(meaning.synonyms) : definitionSynonyms
                let antonyms = definitionAntonyms.isEmpty ? collectWords(meaning.antonyms) : definitionAntonyms
                return WordDefinition(
                    definition: text,
                    example: definition.example?.trimmed,
                    synonyms: synonyms,
                    antonyms: antonyms
                )
            }
            guard !definitions.isEmpty else { return nil }
            return WordMeaning(
                partOfSpeech: part?.isEmpty == true ? nil : part,
                definitions: definitions
            )
        }
    }

    private func mergeMeanings(_ meanings: [WordMeaning]) -> [WordMeaning] {
        guard meanings.count > 1 else { return meanings }
        var merged: [WordMeaning] = []
        var indexByKey: [String: Int] = [:]

        for meaning in meanings {
            let key = meaning.partOfSpeech?.lowercased() ?? "unknown"
            if let index = indexByKey[key] {
                let existing = merged[index]
                var seen = Set<WordDefinition>()
                var combined: [WordDefinition] = []
                for definition in existing.definitions + meaning.definitions {
                    if seen.insert(definition).inserted {
                        combined.append(definition)
                    }
                }
                let part = existing.partOfSpeech ?? meaning.partOfSpeech
                merged[index] = WordMeaning(partOfSpeech: part, definitions: combined)
            } else {
                indexByKey[key] = merged.count
                merged.append(meaning)
            }
        }

        return merged
    }

    private struct DictionaryEntry: Decodable {
        let word: String?
        let meanings: [DictionaryMeaning]
    }

    private struct DictionaryMeaning: Decodable {
        let partOfSpeech: String?
        let definitions: [DictionaryDefinition]
        let synonyms: [String]?
        let antonyms: [String]?
    }

    private struct DictionaryDefinition: Decodable {
        let definition: String?
        let example: String?
        let synonyms: [String]?
        let antonyms: [String]?
    }

    private struct DatamuseEntry: Decodable {
        let word: String?
        let score: Int?
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Array where Element == String {
    func uniquePrefix(_ count: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in self {
            if seen.insert(item.lowercased()).inserted {
                result.append(item)
            }
            if result.count >= count { break }
        }
        return result
    }

    func uniquePrefix(count: Int) -> [String] {
        uniquePrefix(count)
    }
}
