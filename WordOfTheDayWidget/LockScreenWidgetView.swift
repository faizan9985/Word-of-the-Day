// Target membership: WordOfTheDayWidgetExtension only

import SwiftUI
import WidgetKit

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: WordTimelineEntry

    var body: some View {
        widgetContent
            .containerBackground(for: .widget) {
                WidgetDictionaryPalette.paper(colorScheme)
            }
    }

    @ViewBuilder
    private var widgetContent: some View {
        switch family {
        case .accessoryInline:
            Text("\(entry.wordEntry.word) · \(entry.wordEntry.partOfSpeech)")
                .font(.system(.body, design: .serif))

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.wordEntry.word)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .lineLimit(1)

                Text(entry.wordEntry.partOfSpeech)
                    .font(.system(.caption2, design: .serif).italic())
                    .lineLimit(1)

                Text(entry.wordEntry.definition)
                    .font(.system(.caption, design: .serif))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -1) {
                    Text(entry.wordEntry.word.prefix(1).uppercased())
                        .font(.system(.title, design: .serif, weight: .semibold))
                    Text("WOTD")
                        .font(.system(size: 7, weight: .semibold))
                        .tracking(0.5)
                }
            }
            .accessibilityLabel("Word of the day: \(entry.wordEntry.word)")

        case .systemSmall:
            smallWidget

        case .systemMedium:
            mediumWidget

        default:
            Text(entry.wordEntry.word)
                .font(.system(.headline, design: .serif, weight: .semibold))
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 7) {
            WidgetSectionLabel("Word of the Day")

            Rectangle()
                .fill(WidgetDictionaryPalette.accent(colorScheme).opacity(0.75))
                .frame(height: 1)
                .widgetAccentable()
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            Text(entry.wordEntry.word)
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(WidgetDictionaryPalette.ink(colorScheme))
                .minimumScaleFactor(0.72)
                .lineLimit(2)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 5) {
                    Text(entry.wordEntry.partOfSpeech)
                        .font(.system(.caption2, design: .serif).italic())
                    Text("·")
                    Text(entry.wordEntry.phonetic)
                }

                Text(entry.wordEntry.phonetic)
            }
            .font(.caption2)
            .foregroundStyle(WidgetDictionaryPalette.secondaryInk(colorScheme))
            .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("1")
                    .foregroundStyle(WidgetDictionaryPalette.accent(colorScheme))
                    .widgetAccentable()

                Text(entry.wordEntry.definition)
                    .foregroundStyle(WidgetDictionaryPalette.ink(colorScheme))
            }
            .font(.system(.caption, design: .serif))
            .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 7) {
            WidgetSectionLabel("Word of the Day")

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(entry.wordEntry.word)
                    .font(.system(.title, design: .serif, weight: .semibold))
                    .foregroundStyle(WidgetDictionaryPalette.ink(colorScheme))
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(entry.wordEntry.partOfSpeech)
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(WidgetDictionaryPalette.accent(colorScheme))
                    .widgetAccentable()
            }

            Text(entry.wordEntry.phonetic)
                .font(.caption)
                .foregroundStyle(WidgetDictionaryPalette.secondaryInk(colorScheme))
                .lineLimit(1)

            Rectangle()
                .fill(WidgetDictionaryPalette.rule(colorScheme))
                .frame(height: 0.5)
                .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("1")
                    .foregroundStyle(WidgetDictionaryPalette.accent(colorScheme))
                    .widgetAccentable()

                Text(entry.wordEntry.definition)
                    .foregroundStyle(WidgetDictionaryPalette.ink(colorScheme))
            }
            .font(.system(.subheadline, design: .serif))
            .lineLimit(2)

            Text(entry.wordEntry.exampleSentence)
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(WidgetDictionaryPalette.secondaryInk(colorScheme))
                .padding(.leading, 16)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WidgetSectionLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.1)
            .foregroundStyle(WidgetDictionaryPalette.accent(colorScheme))
            .widgetAccentable()
    }
}

private enum WidgetDictionaryPalette {
    static func paper(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.055, green: 0.052, blue: 0.048)
            : Color(red: 0.976, green: 0.969, blue: 0.949)
    }

    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.94, green: 0.92, blue: 0.87)
            : Color(red: 0.075, green: 0.07, blue: 0.065)
    }

    static func secondaryInk(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.66, green: 0.64, blue: 0.60)
            : Color(red: 0.31, green: 0.30, blue: 0.28)
    }

    static func rule(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.18)
            : Color.black.opacity(0.16)
    }

    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.72, green: 0.52, blue: 0.31)
            : Color(red: 0.52, green: 0.34, blue: 0.17)
    }
}
