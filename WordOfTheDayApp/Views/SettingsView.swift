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
    @AppStorage("dailyReminderHour") private var dailyReminderHour = 9
    @AppStorage("dailyReminderMinute") private var dailyReminderMinute = 0
    @State private var errorMessage: String?

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents(
                    [.year, .month, .day],
                    from: Date()
                )
                components.hour = dailyReminderHour
                components.minute = dailyReminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newTime in
                let components = Calendar.current.dateComponents(
                    [.hour, .minute],
                    from: newTime
                )
                guard let hour = components.hour, let minute = components.minute else { return }
                Task { await updateReminderTime(hour: hour, minute: minute) }
            }
        )
    }

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
                Toggle("Daily Notification", isOn: $dailyReminderEnabled)
                    .onChange(of: dailyReminderEnabled) { _, enabled in
                        Task { await updateReminder(enabled: enabled) }
                    }

                if dailyReminderEnabled {
                    DatePicker(
                        "Notification Time",
                        selection: reminderTime,
                        displayedComponents: .hourAndMinute
                    )
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
            try await NotificationService.shared.setDailyReminder(
                enabled: enabled,
                hour: dailyReminderHour,
                minute: dailyReminderMinute
            )
            errorMessage = nil
        } catch {
            dailyReminderEnabled = false
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func updateReminderTime(hour: Int, minute: Int) async {
        do {
            try await NotificationService.shared.setDailyReminder(
                enabled: true,
                hour: hour,
                minute: minute
            )
            dailyReminderHour = hour
            dailyReminderMinute = minute
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
