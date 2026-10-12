import Foundation

@main
struct PrefetchStorageChecks {
    static func main() throws {
        let suite = "word-prefetch-checks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = WordStorage(suiteName: suite)
        let today = Date()
        let tomorrow = WordEntry.nextPacificMidnight(after: today)
        func word(on date: Date) -> WordEntry {
            WordEntry(word: "scheduled", phonetic: "p", partOfSpeech: "noun", definition: "d",
                      exampleSentence: "e", synonyms: ["s"], antonyms: ["a"], date: date,
                      authoritativePacificDateKey: WordEntry.pacificDateKey(for: date))
        }
        let current = word(on: today)
        let next = word(on: tomorrow)
        try storage.saveCurrentWord(current)
        assert(storage.loadPrefetchedWord() == nil)
        try storage.savePrefetchedWord(next)
        let reopened = WordStorage(suiteName: suite)
        assert(reopened.loadCurrentWord() == current)
        assert(reopened.loadPrefetchedWord() == next)
        defaults.set(Data("invalid JSON".utf8), forKey: "prefetchedDailyWord")
        assert(reopened.loadPrefetchedWord() == nil && reopened.loadCurrentWord() == current)
        print("PASS: legacy missing prefetch, separate persisted round-trip, corrupt prefetch isolation")
    }
}
