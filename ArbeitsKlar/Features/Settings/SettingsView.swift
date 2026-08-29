import SwiftUI

private enum SettingsSheet: String, Identifiable {
    case pro

    var id: String { rawValue }
}

@MainActor
struct SettingsView: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(PurchaseManager.self) private var purchases
    @Environment(AppTheme.self) private var theme
    @AppStorage(AppPreferences.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @State private var showsClearConfirmation = false
    @State private var showsReminderPermissionAlert = false
    @State private var presentedSheet: SettingsSheet?

    var body: some View {
        @Bindable var store = store

        Form {
            Section("settings.section.pro") {
                Button {
                    presentedSheet = .pro
                } label: {
                    HStack(spacing: 12) {
                        Label("settings.pro", systemImage: "sparkles")
                        Spacer()
                        Text(proStatusTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(purchases.isPro ? theme.success : theme.accent)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(theme.secondaryLabel)
                    }
                }
                .buttonStyle(.plain)
            }

            Section("settings.section.design") {
                ForEach(AppThemeStyle.allCases) { style in
                    Button {
                        select(style)
                    } label: {
                        HStack(spacing: 12) {
                            ThemeSwatch(style: style)
                            Text(style.title)
                            Spacer()
                            if style.requiresPro, !purchases.isPro {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(theme.warning)
                            } else if theme.style == style {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(theme.success)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                Button {
                    toggleShiftReminder()
                } label: {
                    HStack(spacing: 12) {
                        Label("settings.shift_reminder", systemImage: "bell.badge.fill")
                        Spacer()
                        Text(reminderStatusTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(store.profile.shiftRemindersEnabled ? theme.success : theme.secondaryLabel)
                        Image(systemName: purchases.isPro ? "chevron.right" : "lock.fill")
                            .font(.caption.bold())
                            .foregroundStyle(purchases.isPro ? theme.secondaryLabel : theme.warning)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("settings.section.automation")
            } footer: {
                Text("settings.shift_reminder.note")
            }

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
                    ForEach(PayProfile.supportedCurrencyCodes, id: \.self) { code in
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
                LabeledContent("settings.monthly_goal") {
                    HStack(spacing: 5) {
                        TextField(
                            "settings.monthly_goal",
                            value: $store.profile.monthlyEarningsGoal,
                            format: .number.precision(.fractionLength(0...2))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110)
                        Text(store.profile.currencyCode)
                            .foregroundStyle(theme.secondaryLabel)
                    }
                }
            } header: {
                Text("settings.section.goal")
            } footer: {
                Text("settings.monthly_goal.note")
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

                Button {
                    hasCompletedOnboarding = false
                } label: {
                    Label("settings.show_onboarding", systemImage: "sparkles.rectangle.stack.fill")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .navigationTitle("settings.title")
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .pro:
                ProView()
            }
        }
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
        .alert("reminder.permission.title", isPresented: $showsReminderPermissionAlert) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text("reminder.permission.message")
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var proStatusTitle: LocalizedStringKey {
        if purchases.isPro {
            return "settings.pro.unlocked"
        }
        return "settings.pro.discover"
    }

    private var reminderStatusTitle: LocalizedStringKey {
        store.profile.shiftRemindersEnabled ? "common.on" : "common.off"
    }

    private func select(_ style: AppThemeStyle) {
        if style.requiresPro, !purchases.isPro {
            presentedSheet = .pro
        } else {
            theme.style = style
        }
    }

    private func toggleShiftReminder() {
        guard purchases.isPro else {
            presentedSheet = .pro
            return
        }

        Task {
            let targetValue = !store.profile.shiftRemindersEnabled
            let succeeded = await store.setShiftRemindersEnabled(targetValue)
            if targetValue, !succeeded {
                showsReminderPermissionAlert = true
            }
        }
    }
}

private struct ThemeSwatch: View {
    let style: AppThemeStyle

    var body: some View {
        LinearGradient(
            colors: style.swatchColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: 38, height: 38)
        .clipShape(Circle())
        .overlay {
            Circle().stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsView()
    }
    .environment(WorkSessionStore.preview)
    .environment(PurchaseManager.previewFree)
    .environment(AppTheme())
    .preferredColorScheme(.dark)
}
