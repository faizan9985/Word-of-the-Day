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
    private var attemptedAudioEnrichmentWords = Set<String>()

    init(
        service: any WordAPIProviding = WordAPIService(),
        storage: WordStorage = WordStorage()
    ) {
        self.service = service
        self.storage = storage
        let now = Date()
        let currentDateKey = WordEntry.pacificDateKey(for: now)
        if let savedEntry = storage.loadCurrentWord(),
           WordEntry.pacificCalendar.isDate(savedEntry.date, inSameDayAs: now),
           savedEntry.authoritativePacificDateKey == currentDateKey {
            self.entry = savedEntry
        } else {
            self.entry = .unavailable
        }
    }

    func refresh() async {
        guard !isLoading else { return }

        let now = Date()
        let currentDateKey = WordEntry.pacificDateKey(for: now)
        if let savedEntry = storage.loadCurrentWord(),
           WordEntry.pacificCalendar.isDate(savedEntry.date, inSameDayAs: now),
           savedEntry.authoritativePacificDateKey == currentDateKey {
            entry = savedEntry
            errorMessage = nil

            guard savedEntry.pronunciationAudioURL == nil else { return }

            let wordKey = savedEntry.word.lowercased()
            guard attemptedAudioEnrichmentWords.insert(wordKey).inserted else { return }

            isLoading = true
            defer { isLoading = false }

            do {
                guard let audioURL = try await service.fetchPronunciationAudioURL(
                    for: savedEntry.word
                ) else {
                    return
                }
                try Task.checkCancellation()

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
                try storage.saveCurrentWord(enrichedEntry)
                entry = enrichedEntry
            } catch is CancellationError {
                attemptedAudioEnrichmentWords.remove(wordKey)
            } catch {
                return
            }
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let newEntry = try await service.fetchDailyWord()
            try Task.checkCancellation()

            try storage.saveCurrentWord(newEntry)
            entry = newEntry
            WidgetCenter.shared.reloadAllTimelines()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
