// Target membership: WordOfTheDay app only

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var savedWords: [SavedWord]
    @StateObject private var viewModel = WordViewModel()
    @StateObject private var speechService = SpeechService()

    private var savedCurrentWord: SavedWord? {
        savedWords.first { $0.id == viewModel.entry.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    informationCard(title: "Definition", text: viewModel.entry.definition)
                    informationCard(
                        title: "Example",
                        text: "“\(viewModel.entry.exampleSentence)”",
                        italic: true
                    )
                    wordListCard(
                        title: "Synonyms",
                        words: viewModel.entry.synonyms,
                        emptyMessage: "No synonyms available."
                    )
                    wordListCard(
                        title: "Antonyms",
                        words: viewModel.entry.antonyms,
                        emptyMessage: "No antonyms available."
                    )

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Word of the Day")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: toggleCurrentBookmark) {
                        Image(systemName: savedCurrentWord?.isBookmarked == true ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityLabel(savedCurrentWord?.isBookmarked == true ? "Remove bookmark" : "Bookmark word")

                    NavigationLink(destination: HistoryView()) {
                        Image(systemName: "books.vertical")
                    }
                    .accessibilityLabel("Vocabulary history")

                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                WordHistoryStore.save(viewModel.entry, in: modelContext)
                await viewModel.refresh()
            }
            .onChange(of: viewModel.entry) { _, entry in
                WordHistoryStore.save(entry, in: modelContext)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func toggleCurrentBookmark() {
        if let savedCurrentWord {
            WordHistoryStore.toggleBookmark(for: savedCurrentWord, in: modelContext)
        } else {
            let savedWord = SavedWord(entry: viewModel.entry, isBookmarked: true)
            modelContext.insert(savedWord)
            try? modelContext.save()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(viewModel.entry.word)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)

            HStack(spacing: 10) {
                Text(viewModel.entry.phonetic)
                    .foregroundStyle(.secondary)

                Text(viewModel.entry.partOfSpeech)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundStyle(.tint)
                    .background(.tint.opacity(0.12), in: Capsule())

                Spacer()

                Button {
                    speechService.pronounce(viewModel.entry.word)
                } label: {
                    Label("Pronounce", systemImage: "speaker.wave.2.fill")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .padding(10)
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
                .accessibilityLabel("Pronounce \(viewModel.entry.word)")
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 22)
    }

    private func informationCard(title: String, text: String, italic: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(italic ? .body.italic() : .body)
                .lineSpacing(5)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 18)
    }

    private func wordListCard(title: String, words: [String]?, emptyMessage: String) -> some View {
        let displayText = words?.filter { !$0.isEmpty }.joined(separator: "  •  ") ?? ""
        let hasWords = !displayText.isEmpty

        return VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(hasWords ? displayText : emptyMessage)
                .font(.body)
                .foregroundStyle(hasWords ? Color.primary : Color.secondary)
                .lineSpacing(5)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 18)
    }
}

private extension View {
    func cardStyle(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return background(Color(.secondarySystemGroupedBackground), in: shape)
            .overlay {
                shape.stroke(Color(.separator).opacity(0.65), lineWidth: 1)
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(for: SavedWord.self, inMemory: true)
    }
}
