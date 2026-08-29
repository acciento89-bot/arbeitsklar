import SwiftUI

@MainActor
struct OnboardingView: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferences.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    private let lastPage = 3

    init(initialPage: Int = 0) {
        _currentPage = State(initialValue: min(max(initialPage, 0), 3))
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            backgroundGlow

            VStack(spacing: 0) {
                topBar

                TabView(selection: $currentPage) {
                    OnboardingFeaturePage(
                        kicker: "onboarding.earnings.kicker",
                        title: "onboarding.earnings.title",
                        message: "onboarding.earnings.message",
                        systemImage: "chart.line.uptrend.xyaxis",
                        accent: theme.accent
                    )
                    .tag(0)

                    OnboardingFeaturePage(
                        kicker: "onboarding.breaks.kicker",
                        title: "onboarding.breaks.title",
                        message: "onboarding.breaks.message",
                        systemImage: "pause.circle.fill",
                        accent: theme.success
                    )
                    .tag(1)

                    OnboardingFeaturePage(
                        kicker: "onboarding.planner.kicker",
                        title: "onboarding.planner.title",
                        message: "onboarding.planner.message",
                        systemImage: "calendar.badge.clock",
                        accent: theme.accent
                    )
                    .tag(2)

                    OnboardingSetupPage()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator
            }
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .interactiveDismissDisabled()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Label {
                Text("app.name")
                    .font(.headline.bold())
            } icon: {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(theme.success)
            }

            Spacer()

            if currentPage < lastPage {
                Button("common.skip") {
                    finishOnboarding()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.secondaryLabel)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var pageIndicator: some View {
        HStack(spacing: 7) {
            ForEach(0...lastPage, id: \.self) { page in
                Capsule()
                    .fill(page == currentPage ? theme.accent : .white.opacity(0.16))
                    .frame(width: page == currentPage ? 28 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: currentPage)
        .padding(.bottom, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("onboarding.progress")
        .accessibilityValue(Text("\(currentPage + 1) / \(lastPage + 1)"))
    }

    private var actionBar: some View {
        let buttonTitle: LocalizedStringKey = currentPage == lastPage
            ? "onboarding.start"
            : "onboarding.next"

        return Button {
            if currentPage == lastPage {
                finishOnboarding()
            } else {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    currentPage += 1
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(buttonTitle)
                Image(systemName: currentPage == lastPage ? "checkmark" : "arrow.right")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(.white)
            .background(theme.heroGradient, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .shadow(color: theme.accent.opacity(0.28), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(currentPage == lastPage && store.profile.hourlyRate <= 0)
        .opacity(currentPage == lastPage && store.profile.hourlyRate <= 0 ? 0.45 : 1)
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var backgroundGlow: some View {
        GeometryReader { proxy in
            Circle()
                .fill(theme.accent.opacity(0.15))
                .frame(width: proxy.size.width * 0.9)
                .blur(radius: 70)
                .offset(x: proxy.size.width * 0.5, y: -proxy.size.height * 0.15)

            Circle()
                .fill(theme.success.opacity(0.1))
                .frame(width: proxy.size.width * 0.8)
                .blur(radius: 80)
                .offset(x: -proxy.size.width * 0.35, y: proxy.size.height * 0.55)
        }
        .allowsHitTesting(false)
    }

    private func finishOnboarding() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

private struct OnboardingFeaturePage: View {
    @Environment(AppTheme.self) private var theme

    let kicker: LocalizedStringKey
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    let accent: Color

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Spacer(minLength: 26)

                ZStack {
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .fill(accent.opacity(0.13))
                        .overlay {
                            RoundedRectangle(cornerRadius: 38, style: .continuous)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        }

                    Image(systemName: systemImage)
                        .font(.system(size: 64, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(accent)
                }
                .frame(height: 260)
                .shadow(color: accent.opacity(0.16), radius: 36, y: 22)

                VStack(alignment: .leading, spacing: 12) {
                    Text(kicker)
                        .font(.caption.weight(.bold))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(accent)

                    Text(title)
                        .font(.largeTitle.bold())
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .font(.body)
                        .foregroundStyle(theme.secondaryLabel)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }
}

@MainActor
private struct OnboardingSetupPage: View {
    @Environment(WorkSessionStore.self) private var store
    @Environment(AppTheme.self) private var theme

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("onboarding.setup.kicker")
                        .font(.caption.weight(.bold))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.success)

                    Text("onboarding.setup.title")
                        .font(.largeTitle.bold())
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)

                    Text("onboarding.setup.message")
                        .font(.body)
                        .foregroundStyle(theme.secondaryLabel)
                        .lineSpacing(3)
                }

                VStack(spacing: 0) {
                    LabeledContent {
                        TextField(
                            "settings.hourly_rate",
                            value: $store.profile.hourlyRate,
                            format: .number.precision(.fractionLength(2))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                    } label: {
                        SetupLabel("settings.hourly_rate", systemImage: "banknote.fill")
                    }

                    setupDivider

                    Picker(selection: $store.profile.currencyCode) {
                        ForEach(PayProfile.supportedCurrencyCodes, id: \.self) { code in
                            Text(currencyName(for: code)).tag(code)
                        }
                    } label: {
                        SetupLabel("settings.currency", systemImage: "banknote.fill")
                    }
                    .pickerStyle(.menu)

                    setupDivider

                    Stepper(value: $store.profile.plannedHours, in: 1...16, step: 0.5) {
                        LabeledContent {
                            HStack(spacing: 4) {
                                Text(
                                    store.profile.plannedHours,
                                    format: .number.precision(.fractionLength(0...1))
                                )
                                Text("unit.hours")
                            }
                        } label: {
                            SetupLabel("settings.planned_shift", systemImage: "clock.fill")
                        }
                    }
                }
                .padding(18)
                .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }

                Label("onboarding.setup.privacy", systemImage: "lock.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryLabel)
            }
            .padding(.horizontal, 24)
            .padding(.top, 34)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    private var setupDivider: some View {
        Divider()
            .overlay(.white.opacity(0.08))
            .padding(.vertical, 15)
    }

    private func currencyName(for code: String) -> String {
        if let name = Locale.autoupdatingCurrent.localizedString(forCurrencyCode: code) {
            return "\(code) · \(name)"
        }
        return code
    }
}

private struct SetupLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    init(_ title: LocalizedStringKey, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
    }
}

#Preview("Welcome") {
    OnboardingView()
        .environment(WorkSessionStore.preview)
        .environment(AppTheme())
        .preferredColorScheme(.dark)
}

#Preview("Pay setup") {
    OnboardingView(initialPage: 2)
        .environment(WorkSessionStore.preview)
        .environment(AppTheme())
        .preferredColorScheme(.dark)
}
