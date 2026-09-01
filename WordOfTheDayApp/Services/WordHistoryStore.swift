// Target membership: WordOfTheDay app only

import Foundation
import SwiftData

@MainActor
enum WordHistoryStore {
    static func save(_ entry: WordEntry, in context: ModelContext) {
        let id = entry.id
        let descriptor = FetchDescriptor<SavedWord>(
            predicate: #Predicate { $0.id == id }
        )

        if let saved = try? context.fetch(descriptor).first {
            saved.word = entry.word
            saved.phonetic = entry.phonetic
            saved.partOfSpeech = entry.partOfSpeech
            saved.definitionText = entry.definition
            saved.exampleSentence = entry.exampleSentence
            saved.date = entry.date
        } else {
            context.insert(SavedWord(entry: entry))
        }

        try? context.save()
    }

    static func toggleBookmark(for savedWord: SavedWord, in context: ModelContext) {
        savedWord.isBookmarked.toggle()
        try? context.save()
    }
}
