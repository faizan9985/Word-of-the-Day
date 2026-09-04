// Target membership: WordOfTheDay app + WordOfTheDayWidgetExtension

import Foundation

/// The value shared by the app and its widgets.
struct WordEntry: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let word: String
    let phonetic: String
    let pronunciationAudioURL: URL?
    let partOfSpeech: String
    let definition: String
    let exampleSentence: String
    let synonyms: [String]?
    let antonyms: [String]?
    let date: Date
    let authoritativePacificDateKey: String?

    init(
        id: UUID = UUID(),
        word: String,
        phonetic: String,
        pronunciationAudioURL: URL? = nil,
        partOfSpeech: String,
        definition: String,
        exampleSentence: String,
        synonyms: [String]? = nil,
        antonyms: [String]? = nil,
        date: Date = .now,
        authoritativePacificDateKey: String? = nil
    ) {
        self.id = id
        self.word = word
        self.phonetic = phonetic
        self.pronunciationAudioURL = pronunciationAudioURL
        self.partOfSpeech = partOfSpeech
        self.definition = definition
        self.exampleSentence = exampleSentence
        self.synonyms = synonyms
        self.antonyms = antonyms
        self.date = date
        self.authoritativePacificDateKey = authoritativePacificDateKey
    }
}

extension WordEntry {
    static var pacificCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    static func pacificDateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = pacificCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = pacificCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static let unavailable = WordEntry(
        id: UUID(uuidString: "4D8E370C-492D-44CE-8AF0-A55535F07384")!,
        word: "Unavailable",
        phonetic: "",
        partOfSpeech: "",
        definition: "Open the app while connected to load today’s word.",
        exampleSentence: "",
        date: .distantPast
    )

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
