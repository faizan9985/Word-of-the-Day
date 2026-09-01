// Target membership: WordOfTheDay app only

import Foundation

protocol WordAPIProviding: Sendable {
    func fetchDailyWord() async throws -> WordEntry
}

/// Fetches a daily word from the configured remote service.
struct WordAPIService: WordAPIProviding {
    struct Configuration: Sendable {
        let endpoint: URL?
        let apiKey: String?

        static var appDefault: Configuration {
            let endpointString = Bundle.main.object(
                forInfoDictionaryKey: "WORD_API_ENDPOINT"
            ) as? String
            let apiKey = Bundle.main.object(forInfoDictionaryKey: "WORD_API_KEY") as? String

            return Configuration(
                endpoint: endpointString.flatMap(URL.init(string:)),
                apiKey: apiKey
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
            return try await fetchRemoteWord()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw error
        }
    }

    private func fetchRemoteWord() async throws -> WordEntry {
        guard let endpoint = configuration.endpoint else {
            throw APIError.missingConfiguration
        }

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(DailyWordResponse.self, from: data)
        return payload.wordEntry
    }
}

private extension WordAPIService {
    struct DailyWordResponse: Decodable {
        let id: UUID?
        let word: String
        let phonetic: String
        let partOfSpeech: String
        let definition: String
        let exampleSentence: String
        let synonyms: [String]?
        let antonyms: [String]?
        let date: Date?

        var wordEntry: WordEntry {
            WordEntry(
                id: id ?? UUID(),
                word: word,
                phonetic: phonetic,
                partOfSpeech: partOfSpeech,
                definition: definition,
                exampleSentence: exampleSentence,
                synonyms: synonyms,
                antonyms: antonyms,
                date: date ?? .now
            )
        }
    }

    enum APIError: Error {
        case missingConfiguration
        case invalidResponse
    }
}
