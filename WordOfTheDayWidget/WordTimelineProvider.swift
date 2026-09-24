// Target membership: WordOfTheDayWidgetExtension only

import WidgetKit

struct WordTimelineEntry: TimelineEntry {
    let date: Date
    let wordEntry: WordEntry
}

struct WordTimelineProvider: TimelineProvider {
    var storage = WordStorage()

    func placeholder(in context: Context) -> WordTimelineEntry {
        WordTimelineEntry(date: .now, wordEntry: .fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordTimelineEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordTimelineEntry>) -> Void) {
        let now = Date()
        completion(Timeline(entries: timelineEntries(at: now),
                            policy: .after(WordEntry.nextPacificMidnight(after: now))))
    }

    // Internal for deterministic checks without a WidgetKit Context.
    func timelineEntries(at now: Date) -> [WordTimelineEntry] {
        let current = storage.loadCurrentWord()
        let prefetched = storage.loadPrefetchedWord()
        let midnight = WordEntry.nextPacificMidnight(after: now)
        let followingMidnight = WordEntry.nextPacificMidnight(after: midnight)
        return [now, midnight, followingMidnight].map { date in
            WordTimelineEntry(date: date, wordEntry:
                [current, prefetched].compactMap { $0 }.first { $0.isValid(on: date) } ?? .unavailable)
        }
    }

    private func makeEntry(at date: Date = .now) -> WordTimelineEntry {
        timelineEntries(at: date)[0]
    }
}
