// Target membership: WordOfTheDay app only

import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        rawValue.capitalized
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct SettingsView: View {
    @AppStorage("appAppearance") private var appAppearance = AppAppearance.system.rawValue
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appAppearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Reminders") {
                Toggle("Daily notification at 9:00 AM", isOn: $dailyReminderEnabled)
                    .onChange(of: dailyReminderEnabled) { _, enabled in
                        Task { await updateReminder(enabled: enabled) }
                    }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Widget") {
                Text("Add Word of the Day from the Lock Screen or Home Screen widget gallery.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }

    @MainActor
    private func updateReminder(enabled: Bool) async {
        do {
            try await NotificationService.shared.setDailyReminder(enabled: enabled)
            errorMessage = nil
        } catch {
            dailyReminderEnabled = false
            errorMessage = error.localizedDescription
        }
    }
}
