import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme
    @State private var showsClearConfirmation = false

    private let currencyCodes = [
        "EUR", "USD", "GBP", "CHF", "CAD", "AUD", "NZD", "PLN", "SEK", "NOK", "DKK", "CZK", "JPY"
    ]

    var body: some View {
        @Bindable var store = store

        Form {
            Section("settings.section.pay") {
                LabeledContent("settings.hourly_rate") {
                    TextField(
                        "settings.hourly_rate",
                        value: $store.profile.hourlyRate,
                        format: .number.precision(.fractionLength(2))
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                }

                Picker("settings.currency", selection: $store.profile.currencyCode) {
                    ForEach(currencyCodes, id: \.self) { code in
                        HStack {
                            Text(code)
                            if let name = Locale.autoupdatingCurrent.localizedString(forCurrencyCode: code) {
                                Text(name)
                            }
                        }
                        .tag(code)
                    }
                }

                Stepper(
                    value: $store.profile.plannedHours,
                    in: 1...16,
                    step: 0.5
                ) {
                    LabeledContent("settings.planned_shift") {
                        HStack(spacing: 4) {
                            Text(
                                store.profile.plannedHours,
                                format: .number.precision(.fractionLength(0...1))
                            )
                            Text("unit.hours")
                        }
                    }
                }
            }

            Section {
                LabeledContent("settings.languages") {
                    Text("settings.languages_value")
                        .foregroundStyle(theme.secondaryLabel)
                }

                Label("settings.language_note", systemImage: "globe.europe.africa.fill")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryLabel)
            } header: {
                Text("settings.section.language")
            }

            Section("settings.section.data") {
                LabeledContent("settings.storage") {
                    Text("settings.storage_value")
                        .foregroundStyle(theme.secondaryLabel)
                }

                Button("settings.clear_history", role: .destructive) {
                    showsClearConfirmation = true
                }
                .disabled(store.completedSessions.isEmpty)
            }

            Section("settings.section.about") {
                LabeledContent("settings.version") {
                    Text(version)
                        .foregroundStyle(theme.secondaryLabel)
                }

                Label("settings.privacy", systemImage: "lock.shield.fill")
                    .foregroundStyle(theme.secondaryLabel)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .navigationTitle("settings.title")
        .confirmationDialog(
            "settings.clear_confirm.title",
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("settings.clear_confirm.action", role: .destructive) {
                store.clearCompletedSessions()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.clear_confirm.message")
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsView()
    }
    .environment(WorkSessionStore.preview)
    .environment(AppTheme())
    .preferredColorScheme(.dark)
}

