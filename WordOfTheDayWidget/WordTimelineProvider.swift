// Target membership: WordOfTheDayWidgetExtension only

import WidgetKit

struct WordTimelineEntry: TimelineEntry {
    let date: Date
    let wordEntry: WordEntry
}

struct WordTimelineProvider: TimelineProvider {
    private let storage = WordStorage()

    func placeholder(in context: Context) -> WordTimelineEntry {
        WordTimelineEntry(date: .now, wordEntry: .fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordTimelineEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordTimelineEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(at: now)
        let midnight = WordEntry.nextPacificMidnight(after: now)
        // Expire today's display even if WidgetKit delays requesting a new timeline.
        let expired = WordTimelineEntry(date: midnight, wordEntry: .unavailable)
        completion(Timeline(entries: [entry, expired], policy: .after(midnight)))
    }

    private func makeEntry(at date: Date = .now) -> WordTimelineEntry {
        let savedEntry = storage.loadCurrentWord()
        return WordTimelineEntry(
            date: date,
            wordEntry: savedEntry.flatMap { $0.isCurrent(on: date) ? $0 : nil } ?? .unavailable
        )
    }
}
