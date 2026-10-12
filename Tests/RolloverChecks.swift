// Standalone regression checks: compile with Shared/WordEntry.swift,
// WordOfTheDayApp/Services/WordAPIService.swift and ViewModels/WordViewModel.swift.
// In-memory storage isolates these checks from app-group UserDefaults and SwiftData.
import Foundation

final class WordStorage: @unchecked Sendable {
    nonisolated init() {}
    var prefetched: WordEntry?
    var prefetchWrites: [WordEntry] = []
    func loadPrefetchedWord() -> WordEntry? { prefetched }
    func savePrefetchedWord(_ entry: WordEntry) throws { prefetched = entry; prefetchWrites.append(entry) }
    var saved: WordEntry?
    var writes: [WordEntry] = []
    func loadCurrentWord() -> WordEntry? { saved }
    func saveCurrentWord(_ entry: WordEntry) throws { saved = entry; writes.append(entry) }
}

@MainActor
final class MockService: WordAPIProviding {
    var dailyCalls = 0
    var audioCalls = 0
    var scheduleCalls = 0
    var enrichmentCalls = 0
    var schedule: [String: String] = [:]
    var enrich: (String, String) async throws -> WordEntry = { _, _ in fatalError("Unexpected enrichment") }
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
    func fetchDailySchedule() async throws -> [String: String] { scheduleCalls += 1; return schedule }
    func fetchArchivedWord(_ word: String, pacificDateKey: String) async throws -> WordEntry {
        enrichmentCalls += 1
        return try await enrich(word, pacificDateKey)
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

        let prefetchStorage = WordStorage()
        prefetchStorage.saved = word(before)
        let prefetchService = MockService()
        let midnight = WordEntry.nextPacificMidnight(after: before)
        let tomorrowKey = WordEntry.pacificDateKey(for: midnight)
        prefetchService.schedule = [tomorrowKey: "scheduled"]
        prefetchService.enrich = { value, key in
            assert(value == "scheduled" && key == tomorrowKey)
            // Production enrichment records fetch time, which must be normalized to its target day.
            return word(midnight).scheduled(on: before)
        }
        now = before
        let prefetchModel = WordViewModel(service: prefetchService, storage: prefetchStorage, now: { now })
        await prefetchModel.refresh()
        assert(prefetchStorage.saved!.isValid(on: before) && prefetchStorage.writes.isEmpty)
        assert(prefetchStorage.prefetched!.isValid(on: midnight))
        await prefetchModel.refresh()
        assert(prefetchService.scheduleCalls == 1 && prefetchService.enrichmentCalls == 1)
        print("PASS: authoritative tomorrow prefetch is separate; same-day refresh avoids repeated requests")

        let provider = WordTimelineProvider(storage: prefetchStorage)
        let timeline = provider.timelineEntries(at: before)
        assert(timeline.count == 3 && timeline[0].wordEntry.isValid(on: before))
        assert(timeline[1].date == midnight && timeline[1].wordEntry.authoritativePacificDateKey == tomorrowKey)
        assert(timeline[1].wordEntry.isValid(on: midnight) && timeline[2].wordEntry == .unavailable)
        now = after
        await prefetchModel.refresh()
        assert(prefetchService.dailyCalls == 0 && prefetchStorage.saved!.isValid(on: after))
        assert(prefetchStorage.writes.count == 1)
        assert(prefetchService.scheduleCalls == 2) // Starts the following day's prefetch.
        print("PASS: exact midnight timeline and foreground promotion without daily refetch")

        for invalid in [nil, word(before), WordEntry.unavailable.scheduled(on: midnight)] as [WordEntry?] {
            prefetchStorage.prefetched = invalid
            prefetchStorage.saved = word(before)
            assert(provider.timelineEntries(at: before)[1].wordEntry == .unavailable)
            assert(provider.timelineEntries(at: after)[0].wordEntry == .unavailable)
        }
        prefetchStorage.prefetched = WordEntry(word: "scheduled", phonetic: "p", partOfSpeech: "noun",
            definition: "d", exampleSentence: "e", synonyms: ["s"], antonyms: [],
            date: midnight, authoritativePacificDateKey: tomorrowKey)
        assert(provider.timelineEntries(at: before)[1].wordEntry == .unavailable)
        // Complete payload and target-day timestamp, but the wrong authoritative key.
        prefetchStorage.prefetched = word(before).scheduled(on: midnight)
        assert(provider.timelineEntries(at: before)[1].wordEntry == .unavailable)
        print("PASS: missing, incomplete and wrong-date prefetched values are unavailable")

        for start in ["2026-03-08T08:00:00Z", "2026-11-01T07:00:00Z"] {
            let day = date(start)
            let next = WordEntry.nextPacificMidnight(after: day)
            prefetchStorage.saved = word(day)
            prefetchStorage.prefetched = word(next)
            let entries = provider.timelineEntries(at: day)
            assert(entries[1].date == next)
            assert(entries[1].wordEntry.authoritativePacificDateKey == WordEntry.pacificDateKey(for: next))
        }
        print("PASS: timeline uses exact Pacific keys across spring and fall DST")

        for wrongKey in [false, true] {
            let store = WordStorage()
            store.saved = word(before)
            let api = MockService()
            api.schedule = [tomorrowKey: "scheduled"]
            now = before
            api.enrich = { _, key in
                assert(key == tomorrowKey)
                now = after
                return word(wrongKey ? before : midnight)
            }
            api.fetch = { word(after) }
            let vm = WordViewModel(service: api, storage: store, now: { now })
            await vm.refresh()
            assert(store.prefetchWrites.count == (wrongKey ? 0 : 1))
            assert(store.prefetchWrites.allSatisfy { $0.authoritativePacificDateKey == tomorrowKey && $0.isValid(on: after) })
            assert(store.saved!.isValid(on: after))
            assert(api.dailyCalls == (wrongKey ? 1 : 0))
        }
        print("PASS: prefetch crossing midnight preserves requested date; mismatched result never persists")

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
