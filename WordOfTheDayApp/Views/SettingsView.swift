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
    @Environment(\.colorScheme) private var colorScheme
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
            Section {
                Picker("Theme", selection: $appAppearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(SettingsPalette.paper(colorScheme))
                .listRowSeparatorTint(SettingsPalette.rule(colorScheme))
            } header: {
                SettingsSectionLabel("Appearance")
            }

            Section {
                Toggle("Daily Notification", isOn: $dailyReminderEnabled)
                    .onChange(of: dailyReminderEnabled) { _, enabled in
                        Task { await updateReminder(enabled: enabled) }
                    }
                    .listRowBackground(SettingsPalette.paper(colorScheme))
                    .listRowSeparatorTint(SettingsPalette.rule(colorScheme))

                if dailyReminderEnabled {
                    DatePicker(
                        "Notification Time",
                        selection: reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .listRowBackground(SettingsPalette.paper(colorScheme))
                    .listRowSeparatorTint(SettingsPalette.rule(colorScheme))
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(SettingsPalette.secondaryInk(colorScheme))
                        .accessibilityLabel("Error: \(errorMessage)")
                        .listRowBackground(SettingsPalette.paper(colorScheme))
                        .listRowSeparatorTint(SettingsPalette.rule(colorScheme))
                }
            } header: {
                SettingsSectionLabel("Reminders")
            }

            Section {
                Text("Add Word of the Day from the Lock Screen or Home Screen widget gallery.")
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(SettingsPalette.secondaryInk(colorScheme))
                    .lineSpacing(3)
                    .listRowBackground(SettingsPalette.paper(colorScheme))
                    .listRowSeparatorTint(SettingsPalette.rule(colorScheme))
            } header: {
                SettingsSectionLabel("Widget")
            }
        }
        .font(.body)
        .scrollContentBackground(.hidden)
        .background(SettingsPalette.paper(colorScheme).ignoresSafeArea())
        .tint(SettingsPalette.accent(colorScheme))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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

private struct SettingsSectionLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.5)
            .foregroundStyle(SettingsPalette.accent(colorScheme))
    }
}

private enum SettingsPalette {
    static func paper(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.055, green: 0.052, blue: 0.048)
            : Color(red: 0.976, green: 0.969, blue: 0.949)
    }

    static func secondaryInk(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.66, green: 0.64, blue: 0.60)
            : Color(red: 0.31, green: 0.30, blue: 0.28)
    }

    static func rule(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.16)
    }

    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.72, green: 0.52, blue: 0.31)
            : Color(red: 0.52, green: 0.34, blue: 0.17)
    }
}
