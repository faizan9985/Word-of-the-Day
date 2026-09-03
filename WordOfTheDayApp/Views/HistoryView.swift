// Target membership: WordOfTheDay app only

import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(
        filter: #Predicate<SavedWord> { $0.isBookmarked },
        sort: \SavedWord.date,
        order: .reverse
    ) private var words: [SavedWord]

    var body: some View {
        List {
            if words.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(words) { savedWord in
                        savedWordRow(savedWord)
                            .listRowInsets(
                                EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 16)
                            )
                            .listRowBackground(HistoryPalette.paper(colorScheme))
                            .listRowSeparatorTint(HistoryPalette.rule(colorScheme))
                    }
                    .onDelete(perform: delete)
                } header: {
                    HistorySectionLabel("Saved Dictionary")
                        .padding(.leading, 8)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(HistoryPalette.paper(colorScheme).ignoresSafeArea())
        .navigationTitle("Saved Words")
        .navigationBarTitleDisplayMode(.inline)
        .tint(HistoryPalette.accent(colorScheme))
    }

    private func savedWordRow(_ savedWord: SavedWord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(savedWord.word)
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(HistoryPalette.ink(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                Button {
                    WordHistoryStore.removeBookmark(savedWord, in: modelContext)
                } label: {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(HistoryPalette.accent(colorScheme))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove bookmark for \(savedWord.word)")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    Text(savedWord.partOfSpeech)
                        .italic()
                    Text("·")
                    Text(savedWord.phonetic)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(savedWord.partOfSpeech).italic()
                    Text(savedWord.phonetic)
                }
            }
            .font(.system(.caption, design: .serif))
            .foregroundStyle(HistoryPalette.secondaryInk(colorScheme))

            Text(savedWord.definitionText)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(HistoryPalette.secondaryInk(colorScheme))
                .lineSpacing(3)
                .lineLimit(3)
        }
        .accessibilityElement(children: .contain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bookmark")
                .font(.title2)
                .foregroundStyle(HistoryPalette.accent(colorScheme))

            Text("No Saved Words")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(HistoryPalette.ink(colorScheme))

            Text("Words you bookmark will appear here.")
                .font(.subheadline)
                .foregroundStyle(HistoryPalette.secondaryInk(colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .accessibilityElement(children: .combine)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(words[index])
        }
        try? modelContext.save()
    }
}

private struct HistorySectionLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.5)
            .foregroundStyle(HistoryPalette.accent(colorScheme))
    }
}

private enum HistoryPalette {
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
        scheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.16)
    }

    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.72, green: 0.52, blue: 0.31)
            : Color(red: 0.52, green: 0.34, blue: 0.17)
    }
}
