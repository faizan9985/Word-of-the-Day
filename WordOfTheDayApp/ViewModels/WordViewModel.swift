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

    init(
        service: any WordAPIProviding = WordAPIService(),
        storage: WordStorage = WordStorage()
    ) {
        self.service = service
        self.storage = storage
        self.entry = storage.loadCurrentWord() ?? .fallback
    }

    func refresh() async {
        guard !isLoading else { return }

        if let savedEntry = storage.loadCurrentWord(),
           Calendar.current.isDate(savedEntry.date, inSameDayAs: Date()) {
            entry = savedEntry
            errorMessage = nil
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
