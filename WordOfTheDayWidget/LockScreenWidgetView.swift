// Target membership: WordOfTheDayWidgetExtension only

import SwiftUI
import WidgetKit

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordTimelineEntry

    var body: some View {
        widgetContent
            .containerBackground(for: .widget) {
                widgetBackground
            }
    }

    @ViewBuilder
    private var widgetContent: some View {
        switch family {
        case .accessoryInline:
            Label(entry.wordEntry.word, systemImage: "character.book.closed.fill")

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "character.book.closed.fill")
                    Text(entry.wordEntry.word)
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .lineLimit(1)
                }
                Text(entry.wordEntry.definition)
                    .font(.caption)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -2) {
                    Text(entry.wordEntry.word.prefix(1).uppercased())
                        .font(.system(.title, design: .serif, weight: .bold))
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .accessibilityLabel("Word of the day: \(entry.wordEntry.word)")

        case .systemSmall:
            smallWidget

        case .systemMedium:
            mediumWidget

        default:
            Text(entry.wordEntry.word)
                .font(.system(.headline, design: .serif, weight: .bold))
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WORD OF THE DAY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.indigo)
                    .widgetAccentable()
                Spacer()
                Image(systemName: "character.book.closed.fill")
                    .foregroundStyle(.indigo)
                    .widgetAccentable()
            }

            Spacer(minLength: 2)

            Text(entry.wordEntry.word)
                .font(.system(.title2, design: .serif, weight: .bold))
                .minimumScaleFactor(0.68)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(entry.wordEntry.phonetic)
                    .lineLimit(1)
                Text("·")
                Text(entry.wordEntry.partOfSpeech)
                    .lineLimit(1)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Text(entry.wordEntry.definition)
                .font(.caption)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var mediumWidget: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Label("TODAY", systemImage: "character.book.closed.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.indigo)
                    .widgetAccentable()

                Spacer()

                Text(entry.wordEntry.word)
                    .font(.system(.title, design: .serif, weight: .bold))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)

                Text(entry.wordEntry.phonetic)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(entry.wordEntry.partOfSpeech)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(.indigo)
                    .background(Color.indigo.opacity(0.12), in: Capsule())
                    .widgetAccentable()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("DEFINITION")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.indigo)
                    .widgetAccentable()

                Text(entry.wordEntry.definition)
                    .font(.subheadline)
                    .lineLimit(3)

                Spacer(minLength: 0)

                Text("“\(entry.wordEntry.exampleSentence)”")
                    .font(.caption.italic())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var widgetBackground: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            LinearGradient(
                colors: [Color.indigo.opacity(0.16), .clear, .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
