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

    static func favorite(_ entry: WordEntry, in context: ModelContext) {
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

    static func removeFavorite(_ savedWord: SavedWord, in context: ModelContext) {
        context.delete(savedWord)
        try? context.save()
    }
}

@MainActor
enum ArchiveStore {
    private static let maximumEntryCount = 30

    static func record(_ entry: WordEntry, in context: ModelContext) {
        let descriptor = FetchDescriptor<ArchivedWord>(
            sortBy: [SortDescriptor(\ArchivedWord.date, order: .reverse)]
        )

        do {
            let archivedWords = try context.fetch(descriptor)
            let calendar = Calendar.current
            guard !archivedWords.contains(where: {
                calendar.isDate($0.date, inSameDayAs: entry.date)
            }) else { return }

            context.insert(ArchivedWord(entry: entry))

            let wordsToPrune = archivedWords.dropFirst(maximumEntryCount - 1)
            for archivedWord in wordsToPrune {
                context.delete(archivedWord)
            }
            try context.save()
        } catch {
            return
        }
    }
}
