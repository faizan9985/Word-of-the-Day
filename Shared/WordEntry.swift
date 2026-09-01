// Target membership: WordOfTheDay app + WordOfTheDayWidgetExtension

import Foundation

/// The value shared by the app and its widgets.
struct WordEntry: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let word: String
    let phonetic: String
    let partOfSpeech: String
    let definition: String
    let exampleSentence: String
    let synonyms: [String]?
    let antonyms: [String]?
    let date: Date

    init(
        id: UUID = UUID(),
        word: String,
        phonetic: String,
        partOfSpeech: String,
        definition: String,
        exampleSentence: String,
        synonyms: [String]? = nil,
        antonyms: [String]? = nil,
        date: Date = .now
    ) {
        self.id = id
        self.word = word
        self.phonetic = phonetic
        self.partOfSpeech = partOfSpeech
        self.definition = definition
        self.exampleSentence = exampleSentence
        self.synonyms = synonyms
        self.antonyms = antonyms
        self.date = date
    }
}

extension WordEntry {
    static let fallback = WordEntry(
        id: UUID(uuidString: "7E419745-3F18-48C5-BD29-BA93CA62485E")!,
        word: "Ephemeral",
        phonetic: "/ɪˈfem.ər.əl/",
        partOfSpeech: "adjective",
        definition: "Lasting for only a short time.",
        exampleSentence: "The ephemeral glow of sunset disappeared beneath the horizon.",
        synonyms: ["fleeting", "transient", "momentary", "short-lived"],
        antonyms: ["permanent", "enduring", "lasting", "eternal"]
    )
}
