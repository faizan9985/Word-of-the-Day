// Target membership: WordOfTheDay app only

import Foundation

protocol WordAPIProviding: Sendable {
    func fetchDailyWord() async throws -> WordEntry
}

/// Builds a daily word from bundled candidates and Merriam-Webster lookups.
struct WordAPIService: WordAPIProviding {
    struct Configuration: Sendable {
        let dictionaryAPIKey: String?
        let thesaurusAPIKey: String?

        static var appDefault: Configuration {
            Configuration(
                dictionaryAPIKey: Bundle.main.object(
                    forInfoDictionaryKey: "MW_DICTIONARY_API_KEY"
                ) as? String,
                thesaurusAPIKey: Bundle.main.object(
                    forInfoDictionaryKey: "MW_THESAURUS_API_KEY"
                ) as? String
            )
        }
    }

    private let configuration: Configuration
    private let session: URLSession

    init(
        configuration: Configuration = .appDefault,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    func fetchDailyWord() async throws -> WordEntry {
        do {
            return try await fetchCompleteWord()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw error
        }
    }

    private func fetchCompleteWord() async throws -> WordEntry {
        guard let dictionaryKey = configuration.dictionaryAPIKey,
              !dictionaryKey.isEmpty else {
            throw APIError.missingConfiguration("MW_DICTIONARY_API_KEY")
        }
        guard let thesaurusKey = configuration.thesaurusAPIKey,
              !thesaurusKey.isEmpty else {
            throw APIError.missingConfiguration("MW_THESAURUS_API_KEY")
        }
        guard let dictionaryEndpoint = URL(
            string: "https://www.dictionaryapi.com/api/v3/references/collegiate/json"
        ), let thesaurusEndpoint = URL(
            string: "https://www.dictionaryapi.com/api/v3/references/thesaurus/json"
        ) else {
            throw APIError.invalidURL("Merriam-Webster")
        }

        let maximumAttempts = 10
        let candidates = try loadCandidates().shuffled()
        var attemptedWords = Set<String>()

        for candidate in candidates {
            try Task.checkCancellation()

            let word = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            let candidateKey = word.lowercased()
            guard !word.isEmpty, attemptedWords.insert(candidateKey).inserted else {
                continue
            }
            guard attemptedWords.count <= maximumAttempts else {
                break
            }

            if let entry = try await lookupCandidate(
                word,
                dictionaryEndpoint: dictionaryEndpoint,
                thesaurusEndpoint: thesaurusEndpoint,
                dictionaryKey: dictionaryKey,
                thesaurusKey: thesaurusKey
            ), isComplete(entry) {
                return entry
            }
        }

        throw APIError.noCompleteWord(maximumAttempts)
    }

    private func loadCandidates() throws -> [String] {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json") else {
            throw APIError.missingCandidateList
        }

        do {
            let data = try Data(contentsOf: url)
            let candidateList = try JSONDecoder().decode(CandidateList.self, from: data)
            guard !candidateList.words.isEmpty else {
                throw APIError.emptyCandidateList
            }
            return candidateList.words
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.invalidCandidateList(error)
        }
    }

    private func lookupCandidate(
        _ word: String,
        dictionaryEndpoint: URL,
        thesaurusEndpoint: URL,
        dictionaryKey: String,
        thesaurusKey: String
    ) async throws -> WordEntry? {
        async let dictionaryResults: [DictionaryLookupResult] = request(
            dictionaryEndpoint.appendingPathComponent(word),
            queryItems: [URLQueryItem(name: "key", value: dictionaryKey)],
            name: "dictionary lookup"
        )
        async let thesaurusResults: [ThesaurusLookupResult] = request(
            thesaurusEndpoint.appendingPathComponent(word),
            queryItems: [URLQueryItem(name: "key", value: thesaurusKey)],
            name: "thesaurus lookup"
        )

        let (dictionaryResponse, thesaurusResponse) = try await (
            dictionaryResults,
            thesaurusResults
        )
        try Task.checkCancellation()

        let dictionaryEntries = dictionaryResponse.compactMap(\.entry)
        let thesaurusEntries = thesaurusResponse.compactMap(\.entry)
        guard !dictionaryEntries.isEmpty, !thesaurusEntries.isEmpty else {
            return nil
        }

        let headword = firstNonEmpty(
            dictionaryEntries.map { sanitizeHeadword($0.headword?.text) }
        ) ?? word
        let partOfSpeech = firstNonEmpty(dictionaryEntries.map(\.partOfSpeech)) ?? "Unknown"
        let definition = firstNonEmpty(
            dictionaryEntries.flatMap { ($0.shortDefinitions ?? []).map(sanitize) }
        ) ?? ""
        let pronunciation = firstNonEmpty(
            dictionaryEntries.flatMap { entry in
                entry.headword?.pronunciations?.map { sanitize($0.written) } ?? []
            }
        ) ?? ""
        let example = firstNonEmpty(
            dictionaryEntries.compactMap { firstExample(in: $0.definitionSections) }
        ) ?? ""
        let synonyms = uniqueWords(
            thesaurusEntries.flatMap { ($0.metadata.synonyms ?? []).flatMap { $0 } },
            excluding: word,
            limit: 5
        )
        let antonyms = uniqueWords(
            thesaurusEntries.flatMap { ($0.metadata.antonyms ?? []).flatMap { $0 } },
            excluding: word,
            limit: 5
        )

        return WordEntry(
            word: headword,
            phonetic: pronunciation,
            partOfSpeech: partOfSpeech,
            definition: definition,
            exampleSentence: example,
            synonyms: synonyms,
            antonyms: antonyms
        )
    }

    private func isComplete(_ entry: WordEntry) -> Bool {
        !entry.definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !entry.phonetic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !entry.exampleSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !(entry.synonyms ?? []).isEmpty
            && !(entry.antonyms ?? []).isEmpty
    }

    private func request<Response: Decodable>(
        _ url: URL,
        queryItems: [URLQueryItem],
        name: String
    ) async throws -> Response {
        guard var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL(name)
        }
        components.queryItems = (components.queryItems ?? []) + queryItems
        guard let requestURL = components.url else {
            throw APIError.invalidURL(name)
        }

        var urlRequest = URLRequest(url: requestURL)
        urlRequest.timeoutInterval = 15
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIError.networkFailure(name, error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(name)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpFailure(name, httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decodingFailure(name, error)
        }
    }

    private func firstExample(in sections: [JSONValue]?) -> String? {
        guard let sections else { return nil }
        for section in sections {
            if let example = firstExample(in: section) {
                return example
            }
        }
        return nil
    }

    private func firstExample(in value: JSONValue) -> String? {
        switch value {
        case .array(let values):
            if values.count >= 2,
               case .string("vis") = values[0],
               let example = firstValue(forKey: "t", in: values[1]) {
                return sanitize(example)
            }
            for child in values {
                if let example = firstExample(in: child) {
                    return example
                }
            }
        case .object(let object):
            for child in object.values {
                if let example = firstExample(in: child) {
                    return example
                }
            }
        default:
            break
        }
        return nil
    }

    private func firstValue(forKey key: String, in value: JSONValue) -> String? {
        switch value {
        case .object(let object):
            if case .string(let result) = object[key] {
                return result
            }
            for child in object.values {
                if let result = firstValue(forKey: key, in: child) {
                    return result
                }
            }
        case .array(let values):
            for child in values {
                if let result = firstValue(forKey: key, in: child) {
                    return result
                }
            }
        default:
            break
        }
        return nil
    }

    private func firstNonEmpty(_ values: [String?]) -> String? {
        values.lazy.compactMap { value in
            guard let value else { return nil }
            let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return result.isEmpty ? nil : result
        }.first
    }

    private func uniqueWords(
        _ words: [String],
        excluding originalWord: String,
        limit: Int
    ) -> [String] {
        var seen = Set<String>()
        let originalKey = originalWord.lowercased()
        var results: [String] = []

        for candidate in words {
            let word = sanitize(candidate)
            let key = word.lowercased()
            guard !word.isEmpty, key != originalKey, seen.insert(key).inserted else {
                continue
            }
            results.append(word)
            if results.count == limit {
                break
            }
        }
        return results
    }

    private func sanitize(_ text: String?) -> String {
        guard var text else { return "" }

        let replacements = [
            "{bc}": ": ", "{ldquo}": "\"", "{rdquo}": "\"",
            "{lsquo}": "'", "{rsquo}": "'", "{amp}": "&"
        ]
        for (token, replacement) in replacements {
            text = text.replacingOccurrences(of: token, with: replacement)
        }
        text = text.replacingOccurrences(
            of: #"\{(?:a_link|d_link|i_link|et_link|mat|sx)\|([^|}]+)(?:\|[^}]*)?\}"#,
            with: "$1",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\{[^}]+\}"#,
            with: "",
            options: .regularExpression
        )
        text = text
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitizeHeadword(_ text: String?) -> String {
        sanitize(text)
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(
                of: #":[0-9]+$"#,
                with: "",
                options: .regularExpression
            )
    }
}

private extension WordAPIService {
    struct CandidateList: Decodable {
        let words: [String]
    }

    enum DictionaryLookupResult: Decodable {
        case entry(DictionaryEntry)
        case suggestion(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let suggestion = try? container.decode(String.self) {
                self = .suggestion(suggestion)
            } else {
                self = .entry(try container.decode(DictionaryEntry.self))
            }
        }

        var entry: DictionaryEntry? {
            guard case .entry(let entry) = self else { return nil }
            return entry
        }
    }

    struct DictionaryEntry: Decodable {
        let headword: Headword?
        let partOfSpeech: String?
        let definitionSections: [JSONValue]?
        let shortDefinitions: [String]?

        enum CodingKeys: String, CodingKey {
            case headword = "hwi"
            case partOfSpeech = "fl"
            case definitionSections = "def"
            case shortDefinitions = "shortdef"
        }
    }

    struct Headword: Decodable {
        let text: String?
        let pronunciations: [Pronunciation]?

        enum CodingKeys: String, CodingKey {
            case text = "hw"
            case pronunciations = "prs"
        }
    }

    struct Pronunciation: Decodable {
        let written: String?

        enum CodingKeys: String, CodingKey {
            case written = "mw"
        }
    }

    enum ThesaurusLookupResult: Decodable {
        case entry(ThesaurusEntry)
        case suggestion(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let suggestion = try? container.decode(String.self) {
                self = .suggestion(suggestion)
            } else {
                self = .entry(try container.decode(ThesaurusEntry.self))
            }
        }

        var entry: ThesaurusEntry? {
            guard case .entry(let entry) = self else { return nil }
            return entry
        }
    }

    struct ThesaurusEntry: Decodable {
        let metadata: ThesaurusMetadata

        enum CodingKeys: String, CodingKey {
            case metadata = "meta"
        }
    }

    struct ThesaurusMetadata: Decodable {
        let synonyms: [[String]]?
        let antonyms: [[String]]?

        enum CodingKeys: String, CodingKey {
            case synonyms = "syns"
            case antonyms = "ants"
        }
    }

    enum JSONValue: Decodable {
        case string(String)
        case array([JSONValue])
        case object([String: JSONValue])
        case number(Double)
        case boolean(Bool)
        case null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .null
            } else if let value = try? container.decode(String.self) {
                self = .string(value)
            } else if let value = try? container.decode([JSONValue].self) {
                self = .array(value)
            } else if let value = try? container.decode([String: JSONValue].self) {
                self = .object(value)
            } else if let value = try? container.decode(Double.self) {
                self = .number(value)
            } else if let value = try? container.decode(Bool.self) {
                self = .boolean(value)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unsupported Merriam-Webster JSON value."
                )
            }
        }
    }

    enum APIError: LocalizedError {
        case missingConfiguration(String)
        case missingCandidateList
        case emptyCandidateList
        case invalidCandidateList(Error)
        case invalidURL(String)
        case invalidResponse(String)
        case httpFailure(String, Int)
        case networkFailure(String, Error)
        case decodingFailure(String, Error)
        case noCompleteWord(Int)

        var errorDescription: String? {
            switch self {
            case .missingConfiguration(let key):
                return "Missing Merriam-Webster configuration: \(key)."
            case .missingCandidateList:
                return "The bundled words.json candidate list is missing."
            case .emptyCandidateList:
                return "The bundled words.json candidate list is empty."
            case .invalidCandidateList(let error):
                return "Could not load the bundled words.json candidate list: \(error.localizedDescription)"
            case .invalidURL(let request):
                return "Could not construct the \(request) request."
            case .invalidResponse(let request):
                return "Merriam-Webster returned an invalid response for \(request)."
            case .httpFailure(let request, let statusCode):
                return "Merriam-Webster \(request) failed with HTTP \(statusCode)."
            case .networkFailure(let request, let error):
                return "Merriam-Webster \(request) failed: \(error.localizedDescription)"
            case .decodingFailure(let request, let error):
                return "Could not decode the Merriam-Webster \(request): \(error.localizedDescription)"
            case .noCompleteWord(let attempts):
                return "Could not find a complete word after \(attempts) attempts."
            }
        }
    }
}
