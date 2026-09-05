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
    private static let maximumPublishedDays = 30

    static func normalizeLegacyRows(in context: ModelContext) {
        let descriptor = FetchDescriptor<ArchivedWord>(
            sortBy: [
                SortDescriptor(\ArchivedWord.date, order: .reverse),
                SortDescriptor(\ArchivedWord.id)
            ]
        )

        guard let archivedWords = try? context.fetch(descriptor) else { return }

        var retainedDateKeys = Set<String>()
        for archivedWord in archivedWords {
            let dateKey = archivedWord.pacificDateKey
                ?? WordEntry.pacificDateKey(for: archivedWord.date)

            if retainedDateKeys.insert(dateKey).inserted {
                archivedWord.pacificDateKey = dateKey
            } else {
                context.delete(archivedWord)
            }
        }

        try? context.save()
    }

    static func record(_ entry: WordEntry, in context: ModelContext) {
        normalizeLegacyRows(in: context)

        guard let dateKey = entry.authoritativePacificDateKey,
              let date = pacificDate(from: dateKey) else { return }

        let existingWords = (try? context.fetch(FetchDescriptor<ArchivedWord>())) ?? []
        guard !existingWords.contains(where: { $0.pacificDateKey == dateKey }) else { return }

        context.insert(ArchivedWord(entry: entry, pacificDateKey: dateKey, date: date))
        try? context.save()
    }

    static func sync(
        in context: ModelContext,
        service: any WordAPIProviding = WordAPIService(),
        storage: WordStorage = WordStorage(),
        now: Date = Date()
    ) async {
        normalizeLegacyRows(in: context)

        let schedule: [String: String]
        do {
            schedule = try await service.fetchDailySchedule()
        } catch {
            return
        }

        let currentDateKey = WordEntry.pacificDateKey(for: now)
        let publishedDays = schedule.compactMap { dateKey, word -> PublishedDay? in
            let word = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard dateKey <= currentDateKey,
                  !word.isEmpty,
                  let date = pacificDate(from: dateKey) else {
                return nil
            }
            return PublishedDay(dateKey: dateKey, date: date, word: word)
        }
        .sorted { $0.dateKey > $1.dateKey }
        .prefix(maximumPublishedDays)

        let descriptor = FetchDescriptor<ArchivedWord>()
        let existingWords = (try? context.fetch(descriptor)) ?? []
        var cachedDateKeys = Set(existingWords.compactMap(\.pacificDateKey))
        let currentEntry = storage.loadCurrentWord()

        for day in publishedDays where !cachedDateKeys.contains(day.dateKey) {
            if let currentEntry,
               currentEntry.authoritativePacificDateKey == day.dateKey,
               currentEntry.word.caseInsensitiveCompare(day.word) == .orderedSame {
                let archivedWord = ArchivedWord(
                    entry: currentEntry,
                    pacificDateKey: day.dateKey,
                    date: day.date
                )
                context.insert(archivedWord)
                do {
                    try context.save()
                    cachedDateKeys.insert(day.dateKey)
                } catch {
                    context.delete(archivedWord)
                    continue
                }
                continue
            }

            do {
                let entry = try await service.fetchArchivedWord(
                    day.word,
                    pacificDateKey: day.dateKey
                )
                let archivedWord = ArchivedWord(
                    entry: entry,
                    pacificDateKey: day.dateKey,
                    date: day.date
                )
                context.insert(archivedWord)
                do {
                    try context.save()
                    cachedDateKeys.insert(day.dateKey)
                } catch {
                    context.delete(archivedWord)
                    continue
                }
            } catch is CancellationError {
                return
            } catch {
                continue
            }
        }
    }

    private static func pacificDate(from dateKey: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = WordEntry.pacificCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = WordEntry.pacificCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: dateKey)
    }

    private struct PublishedDay {
        let dateKey: String
        let date: Date
        let word: String
    }
}
