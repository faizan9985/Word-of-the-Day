// Target membership: WordOfTheDay app only

import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<SavedWord> { $0.isBookmarked },
        sort: \SavedWord.date,
        order: .reverse
    ) private var words: [SavedWord]

    var body: some View {
        List {
            if words.isEmpty {
                ContentUnavailableView(
                    "No Saved Words",
                    systemImage: "bookmark",
                    description: Text("Words you bookmark will appear here.")
                )
            } else {
                ForEach(words) { savedWord in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(savedWord.word)
                                .font(.headline)
                            Text(savedWord.partOfSpeech)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                WordHistoryStore.removeBookmark(savedWord, in: modelContext)
                            } label: {
                                Image(systemName: "bookmark.fill")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove bookmark")
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
        .navigationTitle("Saved Words")
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(words[index])
        }
        try? modelContext.save()
    }
}
