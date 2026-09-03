// Target membership: WordOfTheDay app only

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(filter: #Predicate<SavedWord> { $0.isBookmarked }) private var savedWords: [SavedWord]
    @StateObject private var viewModel = WordViewModel()
    @StateObject private var speechService = SpeechService()
    @ScaledMetric(relativeTo: .largeTitle) private var wordSize: CGFloat = 48

    private var savedCurrentWord: SavedWord? {
        savedWords.first { $0.id == viewModel.entry.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    masthead
                        .padding(.bottom, 24)
                    EditorialRule(accented: true)
                    wordHeading
                        .padding(.vertical, 30)
                    EditorialRule()
                    definitionSection
                    EditorialRule()
                    exampleSection
                    EditorialRule()
                    wordListSection(
                        title: "Synonyms",
                        words: viewModel.entry.synonyms,
                        emptyMessage: "No synonyms available."
                    )
                    EditorialRule()
                    wordListSection(
                        title: "Antonyms",
                        words: viewModel.entry.antonyms,
                        emptyMessage: "No antonyms available."
                    )

                    if let errorMessage = viewModel.errorMessage {
                        EditorialRule()
                        errorMessageView(errorMessage)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 48)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(DictionaryPalette.paper(colorScheme).ignoresSafeArea())
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink(destination: HistoryView()) {
                        Image(systemName: "books.vertical")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Saved words")

                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .refreshable { await viewModel.refresh() }
            .task {
                WordHistoryStore.migrateToBookmarkOnlyHistoryIfNeeded(in: modelContext)
                await viewModel.refresh()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Finding today’s word…")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(DictionaryPalette.ink(colorScheme))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(DictionaryPalette.paper(colorScheme))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(DictionaryPalette.rule(colorScheme), lineWidth: 0.5)
                        }
                }
            }
        }
        .tint(DictionaryPalette.ink(colorScheme))
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center) {
                EditorialSectionLabel("Word of the Day")

                Spacer()

                Button(action: toggleCurrentBookmark) {
                    Image(systemName: savedCurrentWord == nil ? "bookmark" : "bookmark.fill")
                        .font(.body.weight(.medium))
                        .foregroundStyle(
                            savedCurrentWord == nil
                                ? DictionaryPalette.ink(colorScheme)
                                : DictionaryPalette.accent(colorScheme)
                        )
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(savedCurrentWord == nil ? "Bookmark word" : "Remove bookmark")
                .accessibilityValue(savedCurrentWord == nil ? "Not bookmarked" : "Bookmarked")
            }

            Text(viewModel.entry.date, format: .dateTime.month(.wide).day().year())
                .font(.caption.weight(.medium))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(DictionaryPalette.secondaryInk(colorScheme))
        }
    }

    private var wordHeading: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(viewModel.entry.displayWord)
                    .font(.system(size: wordSize, weight: .semibold, design: .serif))
                    .foregroundStyle(DictionaryPalette.ink(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 4)

                Button {
                    speechService.pronounce(audioURL: viewModel.entry.pronunciationAudioURL)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.title3)
                        .foregroundStyle(DictionaryPalette.accent(colorScheme))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.entry.pronunciationAudioURL == nil)
                .accessibilityLabel("Pronounce \(viewModel.entry.word)")
            }

            Text(viewModel.entry.phonetic)
                .font(.subheadline)
                .foregroundStyle(DictionaryPalette.secondaryInk(colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Text(viewModel.entry.partOfSpeech)
                .font(.system(.body, design: .serif).italic())
                .foregroundStyle(DictionaryPalette.accent(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var definitionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            EditorialSectionLabel("Definition")

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("1")
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .foregroundStyle(DictionaryPalette.accent(colorScheme))

                Text(viewModel.entry.definition)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(DictionaryPalette.ink(colorScheme))
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.vertical, 28)
    }

    private var exampleSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            EditorialSectionLabel("Example")

            Text(viewModel.entry.exampleSentence)
                .font(.system(.body, design: .serif).italic())
                .foregroundStyle(DictionaryPalette.secondaryInk(colorScheme))
                .lineSpacing(6)
                .padding(.leading, 30)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(.vertical, 28)
    }

    private func wordListSection(title: String, words: [String]?, emptyMessage: String) -> some View {
        let words = words?.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? []

        return VStack(alignment: .leading, spacing: 16) {
            EditorialSectionLabel(title)

            if words.isEmpty {
                Text(emptyMessage)
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(DictionaryPalette.secondaryInk(colorScheme))
            } else {
                Text(words.joined(separator: "  ·  "))
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(DictionaryPalette.ink(colorScheme))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 28)
    }

    private func errorMessageView(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(DictionaryPalette.secondaryInk(colorScheme))
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Error: \(message)")
    }

    private func toggleCurrentBookmark() {
        if let savedCurrentWord {
            WordHistoryStore.removeBookmark(savedCurrentWord, in: modelContext)
        } else {
            WordHistoryStore.bookmark(viewModel.entry, in: modelContext)
        }
    }
}

private struct EditorialSectionLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.6)
            .foregroundStyle(DictionaryPalette.accent(colorScheme))
    }

    @Environment(\.colorScheme) private var colorScheme
}

private struct EditorialRule: View {
    @Environment(\.colorScheme) private var colorScheme
    var accented = false

    var body: some View {
        Rectangle()
            .fill(
                accented
                    ? DictionaryPalette.accent(colorScheme).opacity(0.7)
                    : DictionaryPalette.rule(colorScheme)
            )
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }
}

private enum DictionaryPalette {
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(for: SavedWord.self, inMemory: true)
    }
}
