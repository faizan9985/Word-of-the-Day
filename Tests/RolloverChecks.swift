// Standalone regression checks: compile with Shared/WordEntry.swift,
// WordOfTheDayApp/Services/WordAPIService.swift and ViewModels/WordViewModel.swift.
// In-memory storage isolates these checks from app-group UserDefaults and SwiftData.
import Foundation

@MainActor
final class WordStorage {
    nonisolated init() {}
    var saved: WordEntry?
    var writes: [WordEntry] = []
    func loadCurrentWord() -> WordEntry? { saved }
    func saveCurrentWord(_ entry: WordEntry) throws { saved = entry; writes.append(entry) }
}

@MainActor
final class MockService: WordAPIProviding {
    var dailyCalls = 0
    var audioCalls = 0
    var fetch: () async throws -> WordEntry = { fatalError("Unexpected hosted request") }
    var audio: () async throws -> URL? = { nil }
    func fetchDailyWord() async throws -> WordEntry {
        dailyCalls += 1
        return try await fetch()
    }
    func fetchPronunciationAudioURL(for word: String) async throws -> URL? {
        audioCalls += 1
        return try await audio()
    }
    func fetchDailySchedule() async throws -> [String: String] { fatalError("Unexpected archive request") }
    func fetchArchivedWord(_ word: String, pacificDateKey: String) async throws -> WordEntry {
        fatalError("Unexpected archive request")
    }
}

@main
struct RolloverChecks {
    static func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    static func word(_ date: Date, audio: Bool = true) -> WordEntry {
        WordEntry(word: "scheduled", phonetic: "p", pronunciationAudioURL: audio ? URL(string: "https://example.com/audio") : nil,
                  partOfSpeech: "noun", definition: "d", exampleSentence: "e", synonyms: ["s"], antonyms: ["a"],
                  date: date, authoritativePacificDateKey: WordEntry.pacificDateKey(for: date))
    }

    @MainActor static func main() async throws {
        let before = date("2026-09-05T06:59:59Z")
        let after = date("2026-09-05T07:00:01Z")
        for (start, hours) in [("2026-03-08T08:00:00Z", 23.0), ("2026-11-01T07:00:00Z", 25.0)] {
            let day = date(start)
            assert(WordEntry.nextPacificMidnight(after: day).timeIntervalSince(day) == hours * 3600)
        }
        assert(!word(before).isCurrent(on: after))
        print("PASS: Pacific midnight, DST 23/25-hour days, stale entry rejection")

        var now = before
        let storage = WordStorage()
        storage.saved = word(before)
        let service = MockService()
        let model = WordViewModel(service: service, storage: storage, now: { now })
        await model.refresh()
        await model.refresh()
        assert(service.dailyCalls == 0 && service.audioCalls == 0)
        print("PASS: same-day cache avoids hosted requests")

        service.fetch = { word(now) }
        var waits = 0
        await model.monitorPacificRollover { interval in
            waits += 1
            if waits == 1 {
                assert(interval == 1)
                now = after // Simulate a late timer firing.
            } else { throw CancellationError() }
        }
        assert(service.dailyCalls == 1 && storage.writes.count == 1)
        assert(model.entry.isCurrent(on: after))
        print("PASS: late midnight timer causes exactly one effective refresh")

        now = date("2026-09-06T08:00:00Z")
        await model.monitorPacificRollover { _ in throw CancellationError() }
        assert(service.dailyCalls == 2 && model.entry.isCurrent(on: now))
        await model.monitorPacificRollover { _ in throw CancellationError() }
        assert(service.dailyCalls == 2)
        print("PASS: foreground after midnight refreshes; same-day reactivation reuses cache")

        let crossingStorage = WordStorage()
        let crossingService = MockService()
        now = before
        let crossing = WordViewModel(service: crossingService, storage: crossingStorage, now: { now })
        crossingService.fetch = {
            if crossingService.dailyCalls == 1 {
                // Reentrant trigger while enrichment is suspended must not start a second fetch.
                await crossing.refresh()
                now = after
                return word(before)
            }
            return word(after)
        }
        await crossing.refresh()
        assert(crossingService.dailyCalls == 2)
        assert(crossingStorage.writes.count == 1 && crossingStorage.writes[0].isCurrent(on: after))
        print("PASS: crossing request discarded before save; concurrent trigger coalesced")

        let audioStorage = WordStorage()
        audioStorage.saved = word(before, audio: false)
        let audioService = MockService()
        now = before
        let audioModel = WordViewModel(service: audioService, storage: audioStorage, now: { now })
        audioService.audio = { now = after; return URL(string: "https://example.com/audio") }
        audioService.fetch = { word(after) }
        await audioModel.refresh()
        assert(audioService.dailyCalls == 1 && audioStorage.writes.count == 1)
        assert(audioStorage.writes[0].isCurrent(on: after))
        print("PASS: optional audio crossing midnight cannot save yesterday's entry")

        let staleStorage = WordStorage()
        let staleService = MockService()
        staleService.fetch = { word(before) }
        let stale = WordViewModel(service: staleService, storage: staleStorage, now: { after })
        await stale.refresh()
        assert(staleService.dailyCalls == 3 && staleStorage.writes.isEmpty && stale.errorMessage != nil)
        print("PASS: stale-result retries are bounded and never persisted")

        var isWaiting = false
        let task = Task {
            await model.monitorPacificRollover { _ in
                isWaiting = true
                try await Task.sleep(for: .seconds(3600))
            }
        }
        while !isWaiting { await Task.yield() }
        task.cancel()
        await task.value
        assert(!model.isLoading)
        print("PASS: monitor cancellation exits without a retained timer")
    }
}
