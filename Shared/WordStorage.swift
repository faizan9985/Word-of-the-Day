// Target membership: WordOfTheDay app + WordOfTheDayWidgetExtension

import Foundation

/// Codable storage backed by the shared App Group container.
///
/// Add `group.com.yourapp.wordoftheday` to the App Groups capability for both
/// targets, and replace it here if your production group identifier differs.
struct WordStorage: Sendable {
    static let appGroupIdentifier = "group.com.yourapp.wordoftheday"

    private let suiteName: String
    private let cacheKey = "currentDailyWord"

    init(suiteName: String = Self.appGroupIdentifier) {
        self.suiteName = suiteName
    }

    func loadCurrentWord() -> WordEntry? {
        guard
            let defaults = UserDefaults(suiteName: suiteName),
            let data = defaults.data(forKey: cacheKey)
        else {
            return nil
        }

        return try? JSONDecoder().decode(WordEntry.self, from: data)
    }

    func saveCurrentWord(_ entry: WordEntry) throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw StorageError.appGroupUnavailable(suiteName)
        }

        let data = try JSONEncoder().encode(entry)
        defaults.set(data, forKey: cacheKey)
    }
}

extension WordStorage {
    enum StorageError: LocalizedError {
        case appGroupUnavailable(String)

        var errorDescription: String? {
            switch self {
            case .appGroupUnavailable(let identifier):
                "The App Group \(identifier) is unavailable. Check target entitlements."
            }
        }
    }
}
