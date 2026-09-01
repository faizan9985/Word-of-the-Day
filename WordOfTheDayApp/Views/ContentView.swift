// Target membership: WordOfTheDay app only

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WordViewModel()
    @StateObject private var speechService = SpeechService()

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
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.refresh()
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
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
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
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
