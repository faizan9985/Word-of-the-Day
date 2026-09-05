// Target membership: WordOfTheDay app only

import SwiftData
import SwiftUI
import Photos
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = WordViewModel()
    @State private var selectedTab: AppTab = .today

    var body: some View {
        Group {
            switch selectedTab {
            case .today: NavigationStack { TodayView(viewModel: viewModel) }
            case .archive: NavigationStack { ArchiveView() }
            case .favorites: NavigationStack { FavoritesView() }
            case .settings: NavigationStack { SettingsView() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GlassTabBar(selection: $selectedTab)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await viewModel.monitorPacificRollover()
        }
        .task {
            WordHistoryStore.migrateToBookmarkOnlyHistoryIfNeeded(in: modelContext)
            ArchiveStore.normalizeLegacyRows(in: modelContext)
        }
    }
}

private enum AppTab: String, CaseIterable, Identifiable {
    case today = "Today", archive = "Archive", favorites = "Favorites", settings = "Settings"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .today: "book.closed"
        case .archive: "archivebox"
        case .favorites: "heart.fill"
        case .settings: "gearshape.fill"
        }
    }
}

private struct GlassTabBar: View {
    @Binding var selection: AppTab
    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol).font(.system(size: 17, weight: .semibold))
                        Text(tab.rawValue).font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(selection == tab ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.white.opacity(0.13))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.13), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
    }
}

private struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(filter: #Predicate<SavedWord> { $0.isBookmarked }) private var favorites: [SavedWord]
    @ObservedObject var viewModel: WordViewModel
    @State private var isShowingShareSheet = false

    private var currentFavorite: SavedWord? {
        favorites.first {
            $0.id == viewModel.entry.id || $0.word.caseInsensitiveCompare(viewModel.entry.word) == .orderedSame
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header.padding(.bottom, 20)
                DictionaryRule(accented: true)
                DictionaryWordContent(entry: viewModel.entry)
                if let errorMessage = viewModel.errorMessage {
                    DictionaryRule()
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(AppPalette.secondaryInk(colorScheme))
                        .padding(.vertical, 24)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 28)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppPalette.paper(colorScheme).ignoresSafeArea())
        .refreshable { await refreshAndArchive() }
        .task { await refreshAndArchive() }
        .onChange(of: viewModel.entry) { _, _ in recordCurrentWord() }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Finding today’s word…")
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .tint(AppPalette.accent(colorScheme))
        .sheet(isPresented: $isShowingShareSheet) {
            ShareWordSheet(entry: viewModel.entry)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                DictionarySectionLabel("Word of the Day")
                Spacer()
                FavoriteButton(isFavorite: currentFavorite != nil, action: toggleFavorite)
                Button { isShowingShareSheet = true } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.medium))
                        .frame(width: 36, height: 36)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share \(viewModel.entry.displayWord)")
            }
            Text(viewModel.entry.date, format: Date.FormatStyle(
                date: .long, time: .omitted, calendar: WordEntry.pacificCalendar,
                timeZone: WordEntry.pacificCalendar.timeZone
            ))
                .font(.caption.weight(.medium))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(AppPalette.secondaryInk(colorScheme))
        }
    }

    private func toggleFavorite() {
        if let currentFavorite {
            WordHistoryStore.removeFavorite(currentFavorite, in: modelContext)
        } else {
            WordHistoryStore.favorite(viewModel.entry, in: modelContext)
        }
    }

    @MainActor
    private func refreshAndArchive() async {
        await viewModel.refresh()
        recordCurrentWord()
    }

    @MainActor
    private func recordCurrentWord() {
        guard viewModel.errorMessage == nil,
              viewModel.entry.isCurrent(on: Date()) else { return }
        ArchiveStore.record(viewModel.entry, in: modelContext)
    }
}

struct DictionaryWordContent: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var speechService = SpeechService()
    let entry: WordEntry
    @ScaledMetric(relativeTo: .largeTitle) private var wordSize: CGFloat = 48

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.displayWord)
                        .font(.system(size: wordSize, weight: .semibold, design: .serif))
                        .foregroundStyle(AppPalette.ink(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 4)
                    Button { speechService.pronounce(audioURL: entry.pronunciationAudioURL) } label: {
                        Image(systemName: "speaker.wave.2")
                            .font(.title3)
                            .foregroundStyle(AppPalette.accent(colorScheme))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(entry.pronunciationAudioURL == nil)
                    .accessibilityLabel("Pronounce \(entry.displayWord)")
                }
                Text(entry.phonetic).font(.subheadline)
                    .foregroundStyle(AppPalette.secondaryInk(colorScheme))
                Text(entry.partOfSpeech).font(.system(.body, design: .serif).italic())
                    .foregroundStyle(AppPalette.accent(colorScheme))
            }
            .padding(.vertical, 26)
            DictionaryRule()
            DictionarySection(title: "Definition", number: "1", text: entry.definition)
            DictionaryRule()
            DictionarySection(title: "Example", text: entry.exampleSentence, italic: true)
            DictionaryRule()
            DictionaryWordList(title: "Synonyms", words: entry.synonyms)
            DictionaryRule()
            DictionaryWordList(title: "Antonyms", words: entry.antonyms)
        }
    }
}

private struct DictionarySection: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var number: String?
    let text: String
    var italic = false
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            DictionarySectionLabel(title)
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                if let number { Text(number).foregroundStyle(AppPalette.accent(colorScheme)) }
                Text(text).italic(italic)
                    .foregroundStyle(italic ? AppPalette.secondaryInk(colorScheme) : AppPalette.ink(colorScheme))
                    .lineSpacing(6)
            }
            .font(.system(number == nil ? .body : .title3, design: .serif))
            .padding(.leading, number == nil ? 30 : 0)
        }
        .padding(.vertical, 26)
    }
}

private struct DictionaryWordList: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let words: [String]?
    var body: some View {
        let filtered = words?.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? []
        VStack(alignment: .leading, spacing: 16) {
            DictionarySectionLabel(title)
            Text(filtered.isEmpty ? "No \(title.lowercased()) available." : filtered.joined(separator: "  ·  "))
                .font(.system(.body, design: .serif))
                .foregroundStyle(AppPalette.secondaryInk(colorScheme))
                .lineSpacing(5)
        }
        .padding(.vertical, 26)
    }
}

struct FavoriteButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let isFavorite: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.body.weight(.medium))
                .foregroundStyle(isFavorite ? AppPalette.accent(colorScheme) : AppPalette.ink(colorScheme))
                .frame(width: 36, height: 36)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")
    }
}

struct DictionarySectionLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased()).font(.caption2.weight(.semibold)).tracking(1.6)
            .foregroundStyle(AppPalette.accent(colorScheme))
    }
}

struct DictionaryRule: View {
    @Environment(\.colorScheme) private var colorScheme
    var accented = false
    var body: some View {
        Rectangle()
            .fill(accented ? AppPalette.accent(colorScheme).opacity(0.7) : AppPalette.rule(colorScheme))
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }
}

func shareText(for entry: WordEntry) -> String {
    "Word of the Day\n\(entry.displayWord) \(entry.phonetic) · \(entry.partOfSpeech)\n\(entry.definition)\n\nShared from Word of the Day"
}

struct ShareWordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let entry: WordEntry
    @State private var shareImageItem: ShareImageItem?
    @State private var saveResultMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppPalette.accent(colorScheme))
            }
            .padding(.horizontal, 20)
            .frame(height: 44)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 22) {
                        ShareCardView(entry: entry)
                            .frame(width: 340, height: 340)

                        HStack(spacing: 12) {
                            shareActionButton("Share Image", systemImage: "photo", action: shareImage)
                            shareActionButton("Save Image", systemImage: "square.and.arrow.down", action: saveImage)
                        }

                        ShareLink(item: shareText(for: entry)) {
                            Label("Share Text", systemImage: "text.quote").shareActionStyle()
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(minHeight: geometry.size.height, alignment: .center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(Color.black.opacity(0.94).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(item: $shareImageItem) { item in
            ActivityView(activityItems: [item.image])
                .presentationDetents([.medium, .large])
        }
        .alert("Save Image", isPresented: saveResultIsPresented) {
            Button("OK", role: .cancel) { saveResultMessage = nil }
        } message: {
            Text(saveResultMessage ?? "")
        }
    }

    private var saveResultIsPresented: Binding<Bool> {
        Binding(get: { saveResultMessage != nil }, set: { if !$0 { saveResultMessage = nil } })
    }

    private func shareActionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage).shareActionStyle()
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func shareImage() {
        guard let image = ShareCardRenderer.image(for: entry),
              image.size.width > 0,
              image.size.height > 0,
              image.cgImage != nil else {
            saveResultMessage = "The share image could not be created. Please try again."
            return
        }
        shareImageItem = ShareImageItem(image: image)
    }

    private func saveImage() {
        guard let image = ShareCardRenderer.image(for: entry) else {
            saveResultMessage = "The share image could not be created. Please try again."
            return
        }
        Task {
            do {
                try await ShareCardPhotoSaver.save(image)
                saveResultMessage = "The Word of the Day card was saved to Photos."
            } catch {
                saveResultMessage = error.localizedDescription
            }
        }
    }
}

private struct ShareImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ShareCardView: View {
    let entry: WordEntry

    var body: some View {
        VStack(spacing: 11) {
            Text("WORD OF THE DAY APP")
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(Color(red: 0.52, green: 0.34, blue: 0.17))
            Text("FSS Productions")
                .font(.system(size: 8, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(entry.date, format: .dateTime.month(.wide).day().year())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.displayWord)
                .font(.system(size: 40, weight: .bold, design: .serif))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(.black)
            Text("\(entry.phonetic)  ·  \(entry.partOfSpeech)")
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(.secondary)
            Text(entry.definition)
                .font(.system(.body, design: .serif))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .lineLimit(4)
            Spacer(minLength: 4)
        }
        .padding(24)
        .background(
            Color(red: 0.976, green: 0.969, blue: 0.949),
            in: RoundedRectangle(cornerRadius: 22)
        )
    }
}

@MainActor
private enum ShareCardRenderer {
    static func image(for entry: WordEntry) -> UIImage? {
        let renderer = ImageRenderer(
            content: ShareCardView(entry: entry).frame(width: 340, height: 340)
        )
        renderer.scale = 3
        renderer.isOpaque = false
        return renderer.uiImage
    }
}

private enum ShareCardPhotoSaver {
    static func save(_ image: UIImage) async throws {
        let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard authorization == .authorized || authorization == .limited else {
            throw SaveError.accessDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    enum SaveError: LocalizedError {
        case accessDenied
        var errorDescription: String? {
            "Photos access was denied. You can allow access in Settings and try again."
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private extension View {
    func shareActionStyle() -> some View {
        font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

enum AppPalette {
    static func paper(_ scheme: ColorScheme) -> Color { scheme == .dark ? Color(red: 0.055, green: 0.052, blue: 0.048) : Color(red: 0.976, green: 0.969, blue: 0.949) }
    static func ink(_ scheme: ColorScheme) -> Color { scheme == .dark ? Color(red: 0.94, green: 0.92, blue: 0.87) : Color(red: 0.075, green: 0.07, blue: 0.065) }
    static func secondaryInk(_ scheme: ColorScheme) -> Color { scheme == .dark ? Color(red: 0.66, green: 0.64, blue: 0.60) : Color(red: 0.31, green: 0.30, blue: 0.28) }
    static func rule(_ scheme: ColorScheme) -> Color { scheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.16) }
    static func accent(_ scheme: ColorScheme) -> Color { scheme == .dark ? Color(red: 0.72, green: 0.52, blue: 0.31) : Color(red: 0.52, green: 0.34, blue: 0.17) }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().modelContainer(for: [SavedWord.self, ArchivedWord.self], inMemory: true)
    }
}
