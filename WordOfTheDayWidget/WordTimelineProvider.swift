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
        let entry = makeEntry()
        let pacificCalendar = WordEntry.pacificCalendar
        let midnight = pacificCalendar.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? pacificCalendar.date(byAdding: .day, value: 1, to: .now)!

        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func makeEntry() -> WordTimelineEntry {
        WordTimelineEntry(
            date: .now,
            wordEntry: storage.loadCurrentWord() ?? .unavailable
        )
    }
}
