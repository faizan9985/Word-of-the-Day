// Target membership: WordOfTheDay app only

import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedWord.date, order: .reverse) private var words: [SavedWord]
    @State private var bookmarksOnly = false

    private var visibleWords: [SavedWord] {
        bookmarksOnly ? words.filter(\.isBookmarked) : words
    }

    var body: some View {
        List {
            if visibleWords.isEmpty {
                ContentUnavailableView(
                    bookmarksOnly ? "No Bookmarks" : "No History Yet",
                    systemImage: bookmarksOnly ? "bookmark" : "clock.arrow.circlepath",
                    description: Text("Words you learn will appear here.")
                )
            } else {
                ForEach(visibleWords) { savedWord in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(savedWord.word)
                                .font(.headline)
                            Text(savedWord.partOfSpeech)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                WordHistoryStore.toggleBookmark(
                                    for: savedWord,
                                    in: modelContext
                                )
                            } label: {
                                Image(systemName: savedWord.isBookmarked ? "bookmark.fill" : "bookmark")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(savedWord.isBookmarked ? "Remove bookmark" : "Bookmark")
                        }
                        Text(savedWord.definitionText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Vocabulary")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    bookmarksOnly.toggle()
                } label: {
                    Image(systemName: bookmarksOnly ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(bookmarksOnly ? "Show all words" : "Show bookmarks only")
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(visibleWords[index])
        }
        try? modelContext.save()
    }
}
