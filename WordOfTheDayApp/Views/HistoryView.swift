// Target membership: WordOfTheDay app only

import SwiftData
import SwiftUI

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \ArchivedWord.date, order: .reverse) private var archivedWords: [ArchivedWord]
    @Query(filter: #Predicate<SavedWord> { $0.isBookmarked }) private var favorites: [SavedWord]
    @State private var searchText = ""

    private var filteredWords: [ArchivedWord] {
        let recentWords = Array(archivedWords.prefix(30))
        guard !searchText.isEmpty else { return recentWords }
        return recentWords.filter {
            $0.word.localizedCaseInsensitiveContains(searchText) ||
            $0.definitionText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        WordCollectionScreen(title: "Archive", searchText: $searchText) {
            if filteredWords.isEmpty {
                CollectionEmptyState(
                    symbol: searchText.isEmpty ? "archivebox" : "magnifyingglass",
                    title: searchText.isEmpty ? "Archive Is Empty" : "No Results",
                    message: searchText.isEmpty
                        ? "Daily words you see will collect here for 30 days."
                        : "Try searching for another word or meaning."
                )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filteredWords) { archivedWord in
                        NavigationLink {
                            WordDetailView(entry: archivedWord.wordEntry)
                        } label: {
                            WordCollectionRow(
                                entry: archivedWord.wordEntry,
                                isFavorite: isFavorite(archivedWord.wordEntry)
                            )
                        }
                        .buttonStyle(.plain)
                        DictionaryRule()
                    }
                }
            }
        }
        .background(AppPalette.paper(colorScheme).ignoresSafeArea())
        .task {
            await ArchiveStore.sync(in: modelContext)
        }
    }

    private func isFavorite(_ entry: WordEntry) -> Bool {
        favorites.contains {
            $0.id == entry.id || $0.word.caseInsensitiveCompare(entry.word) == .orderedSame
        }
    }
}

struct FavoritesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(
        filter: #Predicate<SavedWord> { $0.isBookmarked },
        sort: \SavedWord.date,
        order: .reverse
    ) private var favorites: [SavedWord]
    @Query(sort: \ArchivedWord.date, order: .reverse) private var archivedWords: [ArchivedWord]

    var body: some View {
        WordCollectionScreen(title: "Favorites") {
            if favorites.isEmpty {
                CollectionEmptyState(
                    symbol: "heart",
                    title: "No Favorites Yet",
                    message: "Words you favorite will appear here."
                )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(favorites) { favorite in
                        NavigationLink {
                            WordDetailView(entry: detailEntry(for: favorite))
                        } label: {
                            WordCollectionRow(entry: favorite.wordEntry, isFavorite: true)
                        }
                        .buttonStyle(.plain)
                        DictionaryRule()
                    }
                }
            }
        }
        .background(AppPalette.paper(colorScheme).ignoresSafeArea())
    }

    private func detailEntry(for favorite: SavedWord) -> WordEntry {
        archivedWords.first {
            $0.id == favorite.id || $0.word.caseInsensitiveCompare(favorite.word) == .orderedSame
        }?.wordEntry ?? favorite.wordEntry
    }
}

private struct WordCollectionScreen<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    private let searchText: Binding<String>?
    @ViewBuilder let content: Content

    init(
        title: String,
        searchText: Binding<String>? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.searchText = searchText
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(title)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.ink(colorScheme))

                if let searchText {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppPalette.secondaryInk(colorScheme))
                        TextField("Search words and meanings", text: searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppPalette.rule(colorScheme), lineWidth: 0.5)
                    }
                }

                content
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 30)
        }
        .background(AppPalette.paper(colorScheme).ignoresSafeArea())
        .navigationBarHidden(true)
        .tint(AppPalette.accent(colorScheme))
    }
}

private struct WordCollectionRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: WordEntry
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(entry.displayWord)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(AppPalette.ink(colorScheme))
                    if isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(AppPalette.accent(colorScheme))
                    }
                }
                Text(entry.definition)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.secondaryInk(colorScheme))
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Text(entry.date, format: .dateTime.month(.abbreviated).day())
                .font(.caption)
                .foregroundStyle(AppPalette.secondaryInk(colorScheme))
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.secondaryInk(colorScheme))
        }
        .padding(.vertical, 17)
        .contentShape(Rectangle())
    }
}

private struct CollectionEmptyState: View {
    @Environment(\.colorScheme) private var colorScheme
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 13) {
            Image(systemName: symbol).font(.title2)
                .foregroundStyle(AppPalette.accent(colorScheme))
            Text(title).font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(AppPalette.ink(colorScheme))
            Text(message).font(.subheadline)
                .foregroundStyle(AppPalette.secondaryInk(colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 340)
    }
}

struct WordDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(filter: #Predicate<SavedWord> { $0.isBookmarked }) private var favorites: [SavedWord]
    let entry: WordEntry
    @State private var isShowingShareSheet = false

    private var favorite: SavedWord? {
        favorites.first {
            $0.id == entry.id || $0.word.caseInsensitiveCompare(entry.word) == .orderedSame
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(entry.date, format: .dateTime.month(.wide).day().year())
                        .font(.caption.weight(.medium))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(AppPalette.secondaryInk(colorScheme))
                    Spacer()
                    FavoriteButton(isFavorite: favorite != nil, action: toggleFavorite)
                    Button { isShowingShareSheet = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 36, height: 36)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share \(entry.displayWord)")
                }
                DictionaryRule(accented: true)
                    .padding(.top, 16)
                DictionaryWordContent(entry: entry)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(AppPalette.paper(colorScheme).ignoresSafeArea())
        .navigationTitle(entry.displayWord)
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppPalette.accent(colorScheme))
        .sheet(isPresented: $isShowingShareSheet) {
            ShareWordSheet(entry: entry)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func toggleFavorite() {
        if let favorite {
            WordHistoryStore.removeFavorite(favorite, in: modelContext)
        } else {
            WordHistoryStore.favorite(entry, in: modelContext)
        }
    }
}
