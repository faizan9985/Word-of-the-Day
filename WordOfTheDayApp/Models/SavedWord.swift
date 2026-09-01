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
