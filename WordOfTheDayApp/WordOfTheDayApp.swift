// Target membership: WordOfTheDay app only

import SwiftUI
import SwiftData

@main
struct WordOfTheDayApp: App {
    @AppStorage("appAppearance") private var appAppearance = AppAppearance.system.rawValue

    private var preferredColorScheme: ColorScheme? {
        AppAppearance(rawValue: appAppearance)?.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(preferredColorScheme)
        }
        .modelContainer(for: SavedWord.self)
    }
}
