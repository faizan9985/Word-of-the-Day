// Target membership: WordOfTheDay app only

import Combine
import Foundation
import WidgetKit

@MainActor
final class WordViewModel: ObservableObject {
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
           savedEntry.isCurrent(on: now()) {
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

        do {
            // Bound retries if the clock keeps changing or a service returns stale results.
            for _ in 0..<3 {
                try Task.checkCancellation()
                if let savedEntry = storage.loadCurrentWord(), savedEntry.isCurrent(on: now()) {
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
                        if !savedEntry.isCurrent(on: now()) { continue }
                        return
                    }
                    guard savedEntry.isCurrent(on: now()) else { continue }
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
                    guard enrichedEntry.isCurrent(on: now()) else { continue }
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
                guard newEntry.isCurrent(on: now()) else { continue }
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
