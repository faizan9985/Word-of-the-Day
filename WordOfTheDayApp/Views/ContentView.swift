// Target membership: WordOfTheDay app only

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SavedWord> { $0.isBookmarked }) private var savedWords: [SavedWord]
    @StateObject private var viewModel = WordViewModel()
    @StateObject private var speechService = SpeechService()

    private var savedCurrentWord: SavedWord? {
        savedWords.first { $0.id == viewModel.entry.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    heroCard
                    informationCard(title: "Definition", systemImage: "text.quote", text: viewModel.entry.definition)
                    informationCard(
                        title: "In a sentence",
                        systemImage: "quote.opening",
                        text: "“\(viewModel.entry.exampleSentence)”",
                        italic: true
                    )
                    wordListCard(
                        title: "Synonyms",
                        systemImage: "arrow.triangle.branch",
                        words: viewModel.entry.synonyms,
                        emptyMessage: "No synonyms available."
                    )
                    wordListCard(
                        title: "Antonyms",
                        systemImage: "arrow.left.arrow.right",
                        words: viewModel.entry.antonyms,
                        emptyMessage: "No antonyms available."
                    )

                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(errorMessage)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(pageBackground)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink(destination: HistoryView()) {
                        Image(systemName: "books.vertical")
                    }
                    .accessibilityLabel("Saved words")

                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
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
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                }
            }
        }
        .tint(.indigo)
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: [
                Color.indigo.opacity(0.10),
                Color(.systemGroupedBackground),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .center
        )
        .ignoresSafeArea()
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label {
                    Text(viewModel.entry.date, format: .dateTime.weekday(.wide).month(.wide).day())
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "character.book.closed.fill")
                    .font(.title3)
                    .foregroundStyle(.indigo)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.entry.word)
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .minimumScaleFactor(0.72)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 10) {
                    Text(viewModel.entry.phonetic)
                        .foregroundStyle(.secondary)

                    Text(viewModel.entry.partOfSpeech)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundStyle(.indigo)
                        .background(Color.indigo.opacity(0.12), in: Capsule())
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    speechService.pronounce(audioURL: viewModel.entry.pronunciationAudioURL)
                } label: {
                    Label("Listen", systemImage: "speaker.wave.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.entry.pronunciationAudioURL == nil)
                .accessibilityLabel("Pronounce \(viewModel.entry.word)")

                Button(action: toggleCurrentBookmark) {
                    Label(
                        savedCurrentWord == nil ? "Save" : "Saved",
                        systemImage: savedCurrentWord == nil ? "bookmark" : "bookmark.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(savedCurrentWord == nil ? "Bookmark word" : "Remove bookmark")
            }
            .controlSize(.large)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.indigo.opacity(0.14), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.indigo.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: Color.indigo.opacity(0.08), radius: 20, y: 10)
    }

    private func informationCard(
        title: String,
        systemImage: String,
        text: String,
        italic: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title, systemImage: systemImage)
            Text(text)
                .font(italic ? .body.italic() : .body)
                .lineSpacing(5)
                .textSelection(.enabled)
        }
        .contentCard()
    }

    private func wordListCard(
        title: String,
        systemImage: String,
        words: [String]?,
        emptyMessage: String
    ) -> some View {
        let words = words?.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? []

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title, systemImage: systemImage)

            if words.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                TagFlowLayout(spacing: 8) {
                    ForEach(words, id: \.self) { word in
                        Text(word)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.indigo.opacity(0.10), in: Capsule())
                    }
                }
            }
        }
        .contentCard()
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title.uppercased(), systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(.indigo)
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
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

private extension View {
    func contentCard() -> some View {
        padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(.separator).opacity(0.45), lineWidth: 0.5)
            }
    }
}

private struct TagFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? .infinity
        var position = CGPoint.zero
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if position.x > 0, position.x + size.width > width {
                position.x = 0
                position.y += rowHeight + spacing
                rowHeight = 0
            }
            position.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width.isFinite ? width : position.x, height: position.y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var position = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if position.x > bounds.minX, position.x + size.width > bounds.maxX {
                position.x = bounds.minX
                position.y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: position, proposal: ProposedViewSize(size))
            position.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(for: SavedWord.self, inMemory: true)
    }
}
