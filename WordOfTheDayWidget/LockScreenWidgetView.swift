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
            Text("\(entry.wordEntry.displayWord) · \(entry.wordEntry.partOfSpeech)")
                .font(.system(.body, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.wordEntry.displayWord)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)

                Text(entry.wordEntry.partOfSpeech)
                    .font(.system(.caption2, design: .serif).italic())
                    .foregroundStyle(.secondary)
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
                VStack(spacing: 0) {
                    Text(entry.wordEntry.displayWord.prefix(1))
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                    Text(entry.wordEntry.partOfSpeech.prefix(4))
                        .font(.system(size: 7, design: .serif).italic())
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Word of the day: \(entry.wordEntry.displayWord)")

        case .systemSmall:
            smallWidget

        case .systemMedium:
            mediumWidget

        default:
            Text(entry.wordEntry.displayWord)
                .font(.system(.headline, design: .serif, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .allowsTightening(true)
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.wordEntry.displayWord)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(WidgetDictionaryPalette.ink(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .allowsTightening(true)

            Text(entry.wordEntry.partOfSpeech)
                .font(.system(.caption2, design: .serif).italic())
                .foregroundStyle(WidgetDictionaryPalette.secondaryInk(colorScheme))
                .lineLimit(1)

            Rectangle()
                .fill(WidgetDictionaryPalette.accent(colorScheme).opacity(0.75))
                .frame(height: 1)
                .widgetAccentable()
                .accessibilityHidden(true)

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
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(entry.wordEntry.displayWord)
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(WidgetDictionaryPalette.ink(colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
                    .layoutPriority(3)

                Text(entry.wordEntry.phonetic)
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(WidgetDictionaryPalette.secondaryInk(colorScheme))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .layoutPriority(2)

                Text(entry.wordEntry.partOfSpeech)
                    .font(.system(.caption2, design: .serif).italic())
                    .foregroundStyle(WidgetDictionaryPalette.secondaryInk(colorScheme))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer(minLength: 0)
            }
            .layoutPriority(3)

            Rectangle()
                .fill(WidgetDictionaryPalette.accent(colorScheme).opacity(0.75))
                .frame(height: 1)
                .widgetAccentable()
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
            .layoutPriority(2)

            Text(entry.wordEntry.exampleSentence)
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(WidgetDictionaryPalette.secondaryInk(colorScheme))
                .padding(.leading, 17)
                .lineLimit(2)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
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
