// Target membership: WordOfTheDay app only

import SwiftUI
import SwiftData
import BackgroundTasks
import OSLog

@main
struct WordOfTheDayApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private static let refreshIdentifier = "com.yourapp.wordoftheday.prefetch"

    @AppStorage("appAppearance") private var appAppearance = AppAppearance.system.rawValue

    private var preferredColorScheme: ColorScheme? {
        AppAppearance(rawValue: appAppearance)?.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(preferredColorScheme)
        }
        .modelContainer(for: [SavedWord.self, ArchivedWord.self])
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Self.scheduleRefresh() }
        }
        .backgroundTask(.appRefresh(Self.refreshIdentifier)) {
            await Self.scheduleRefresh()
            await WordViewModel.shared.refresh()
        }
    }

    private static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        let now = Date()
        // An evening opportunity, or a retry in an hour if already late. iOS decides execution.
        let evening = WordEntry.pacificCalendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)!
        request.earliestBeginDate = max(evening, now.addingTimeInterval(3600))
        do { try BGTaskScheduler.shared.submit(request) }
        catch { Logger().debug("Word background refresh scheduling failed: \(error.localizedDescription)") }
    }
}
