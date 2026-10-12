// Target membership: WordOfTheDay app only

import Combine
import Foundation
import WidgetKit

@MainActor
final class WordViewModel: ObservableObject {
    static let shared = WordViewModel()
    @Published private(set) var entry: WordEntry
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: any WordAPIProviding
    private let storage: WordStorage
    private let now: () -> Date
    private var attemptedAudioEnrichmentWords = Set<String>()

    init(
        service: any WordAPIProviding = WordAPIService(),
        storage: WordStorage = WordStorage(),
        now: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.storage = storage
        self.now = now
        if let savedEntry = storage.loadCurrentWord(),
           savedEntry.isValid(on: now()) {
            self.entry = savedEntry
        } else {
            self.entry = .unavailable
        }
    }

    /// Owned by SwiftUI's scene task: cancellation stops the one-shot midnight wait.
    /// No stored task or timer retains this view model.
    func monitorPacificRollover(
        sleep: (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }
    ) async {
        do {
            while !Task.isCancelled {
                // A canceled scene task or a pull-to-refresh may still be unwinding.
                while isLoading {
                    try await Task.sleep(for: .milliseconds(50))
                }
                try Task.checkCancellation()
                await refresh()
                try Task.checkCancellation()
                let date = now()
                let interval = WordEntry.nextPacificMidnight(after: date).timeIntervalSince(date)
                try await sleep(interval)
            }
        } catch {
            // Scene inactivity or view removal cancels the wait; activation starts a new check.
        }
    }

    func refresh() async {
        guard !isLoading, !Task.isCancelled else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Keep foreground and background work under the same in-flight guard.
        for _ in 0..<3 {
            await refreshCurrent()
            guard !Task.isCancelled, entry.isValid(on: now()) else { return }
            let dayKey = WordEntry.pacificDateKey(for: now())
            await prefetchTomorrow()
            if dayKey == WordEntry.pacificDateKey(for: now()) { return }
        }
    }

    private func prefetchTomorrow() async {
        let targetDate = WordEntry.nextPacificMidnight(after: now())
        let targetKey = WordEntry.pacificDateKey(for: targetDate)
        guard storage.loadPrefetchedWord()?.isValid(on: targetDate) != true else { return }
        do {
            let schedule = try await service.fetchDailySchedule()
            try Task.checkCancellation()
            guard let word = schedule[targetKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !word.isEmpty else { return }
            let result = try await service.fetchArchivedWord(word, pacificDateKey: targetKey)
            try Task.checkCancellation()
            // Never relabel a result using the clock at completion. If midnight passed,
            // this exact requested day can be promoted by the next refresh iteration.
            let date = now()
            guard result.authoritativePacificDateKey == targetKey, result.isComplete,
                  targetKey == WordEntry.pacificDateKey(for: date)
                    || targetKey == WordEntry.pacificDateKey(for: WordEntry.nextPacificMidnight(after: date))
            else { return }
            try storage.savePrefetchedWord(result.scheduled(on: targetDate))
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Tomorrow's failure must not hide a valid word today. A later refresh retries.
        }
    }

    private func refreshCurrent() async {
        do {
            // Bound retries if the clock keeps changing or a service returns stale results.
            for _ in 0..<3 {
                try Task.checkCancellation()
                let date = now()
                if storage.loadCurrentWord()?.isValid(on: date) != true,
                   let prefetched = storage.loadPrefetchedWord(), prefetched.isValid(on: date) {
                    try storage.saveCurrentWord(prefetched)
                    entry = prefetched
                    WidgetCenter.shared.reloadAllTimelines()
                    return
                }
                if let savedEntry = storage.loadCurrentWord(), savedEntry.isValid(on: now()) {
                    entry = savedEntry
                    guard savedEntry.pronunciationAudioURL == nil else { return }
                    let wordKey = savedEntry.word.lowercased()
                    guard attemptedAudioEnrichmentWords.insert(wordKey).inserted else { return }

                    let audioURL: URL?
                    do {
                        audioURL = try await service.fetchPronunciationAudioURL(for: savedEntry.word)
                        try Task.checkCancellation()
                    } catch is CancellationError {
                        attemptedAudioEnrichmentWords.remove(wordKey)
                        throw CancellationError()
                    } catch {
                        // Optional audio failure must not prevent a rollover during this request.
                        if !savedEntry.isValid(on: now()) { continue }
                        return
                    }
                    guard savedEntry.isValid(on: now()) else { continue }
                    guard let audioURL else { return }
                    let enrichedEntry = WordEntry(
                        id: savedEntry.id,
                        word: savedEntry.word,
                        phonetic: savedEntry.phonetic,
                        pronunciationAudioURL: audioURL,
                        partOfSpeech: savedEntry.partOfSpeech,
                        definition: savedEntry.definition,
                        exampleSentence: savedEntry.exampleSentence,
                        synonyms: savedEntry.synonyms,
                        antonyms: savedEntry.antonyms,
                        date: savedEntry.date,
                        authoritativePacificDateKey: savedEntry.authoritativePacificDateKey
                    )
                    // No suspension between the final date check and save/publish.
                    guard enrichedEntry.isValid(on: now()) else { continue }
                    try storage.saveCurrentWord(enrichedEntry)
                    entry = enrichedEntry
                    WidgetCenter.shared.reloadAllTimelines()
                    return
                }

                entry = .unavailable
                let requestedDateKey = WordEntry.pacificDateKey(for: now())
                let newEntry: WordEntry
                do {
                    newEntry = try await service.fetchDailyWord()
                } catch {
                    try Task.checkCancellation()
                    if requestedDateKey != WordEntry.pacificDateKey(for: now()) { continue }
                    throw error
                }
                try Task.checkCancellation()
                guard newEntry.isValid(on: now()) else { continue }
                // MainActor-isolated synchronous save/publish; no await after validation.
                try storage.saveCurrentWord(newEntry)
                entry = newEntry
                WidgetCenter.shared.reloadAllTimelines()
                return
            }
            entry = .unavailable
            errorMessage = "The Pacific date changed while loading today’s word. Please try again."
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
