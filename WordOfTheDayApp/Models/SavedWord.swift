// Target membership: WordOfTheDay app only

import Foundation
import SwiftData

@Model
final class SavedWord {
    @Attribute(.unique) var id: UUID
    var word: String
    var phonetic: String
    var partOfSpeech: String
    var definitionText: String
    var exampleSentence: String
    var date: Date
    var isBookmarked: Bool

    init(entry: WordEntry, isBookmarked: Bool = false) {
        self.id = entry.id
        self.word = entry.word
        self.phonetic = entry.phonetic
        self.partOfSpeech = entry.partOfSpeech
        self.definitionText = entry.definition
        self.exampleSentence = entry.exampleSentence
        self.date = entry.date
        self.isBookmarked = isBookmarked
    }

    var wordEntry: WordEntry {
        WordEntry(
            id: id,
            word: word,
            phonetic: phonetic,
            partOfSpeech: partOfSpeech,
            definition: definitionText,
            exampleSentence: exampleSentence,
            synonyms: nil,
            antonyms: nil,
            date: date
        )
    }
}

@Model
final class ArchivedWord {
    @Attribute(.unique) var id: UUID
    var word: String
    var phonetic: String
    var pronunciationAudioURL: URL?
    var partOfSpeech: String
    var definitionText: String
    var exampleSentence: String
    var synonyms: [String]?
    var antonyms: [String]?
    var date: Date

    init(entry: WordEntry) {
        self.id = entry.id
        self.word = entry.word
        self.phonetic = entry.phonetic
        self.pronunciationAudioURL = entry.pronunciationAudioURL
        self.partOfSpeech = entry.partOfSpeech
        self.definitionText = entry.definition
        self.exampleSentence = entry.exampleSentence
        self.synonyms = entry.synonyms
        self.antonyms = entry.antonyms
        self.date = entry.date
    }

    var wordEntry: WordEntry {
        WordEntry(
            id: id,
            word: word,
            phonetic: phonetic,
            pronunciationAudioURL: pronunciationAudioURL,
            partOfSpeech: partOfSpeech,
            definition: definitionText,
            exampleSentence: exampleSentence,
            synonyms: synonyms,
            antonyms: antonyms,
            date: date
        )
    }
}
