// Target membership: WordOfTheDay app only

import Foundation
import SwiftData

@MainActor
enum WordHistoryStore {
    private static let bookmarkOnlyMigrationKey = "didMigrateToBookmarkOnlyHistoryV1"

    static func migrateToBookmarkOnlyHistoryIfNeeded(in context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: bookmarkOnlyMigrationKey) else { return }

        let descriptor = FetchDescriptor<SavedWord>(
            predicate: #Predicate { !$0.isBookmarked }
        )

        do {
            for savedWord in try context.fetch(descriptor) {
                context.delete(savedWord)
            }
            try context.save()
            UserDefaults.standard.set(true, forKey: bookmarkOnlyMigrationKey)
        } catch {
            return
        }
    }

    static func bookmark(_ entry: WordEntry, in context: ModelContext) {
        let existingWord = (try? context.fetch(FetchDescriptor<SavedWord>()))?.first {
            $0.id == entry.id || $0.word.caseInsensitiveCompare(entry.word) == .orderedSame
        }

        if let existingWord {
            existingWord.isBookmarked = true
        } else {
            context.insert(SavedWord(entry: entry, isBookmarked: true))
        }

        try? context.save()
    }

    static func removeBookmark(_ savedWord: SavedWord, in context: ModelContext) {
        context.delete(savedWord)
        try? context.save()
    }
}
