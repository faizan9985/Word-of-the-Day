// Target membership: WordOfTheDayWidgetExtension only

import SwiftUI
import WidgetKit

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordTimelineEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Word: \(entry.wordEntry.word)")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.wordEntry.word)
                    .font(.headline)
                    .bold()
                    .lineLimit(1)
                Text(entry.wordEntry.definition)
                    .font(.caption)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Text(entry.wordEntry.word.prefix(1).uppercased())
                    .font(.title.bold())
            }
            .accessibilityLabel("Word of the day: \(entry.wordEntry.word)")
        case .systemSmall:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "text.book.closed.fill")
                    .foregroundStyle(.tint)
                Spacer()
                Text(entry.wordEntry.word)
                    .font(.title2.bold())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(entry.wordEntry.definition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case .systemMedium:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(entry.wordEntry.word)
                        .font(.title.bold())
                    Spacer()
                    Text(entry.wordEntry.partOfSpeech)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.tint.opacity(0.15), in: Capsule())
                }
                Text(entry.wordEntry.phonetic)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(entry.wordEntry.definition)
                    .font(.body)
                    .lineLimit(2)
                Spacer()
                Text("“\(entry.wordEntry.exampleSentence)”")
                    .font(.caption.italic())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        default:
            Text(entry.wordEntry.word)
        }
    }
}
