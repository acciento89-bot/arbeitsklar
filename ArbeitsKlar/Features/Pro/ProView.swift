import SwiftUI

@MainActor
struct ProView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var issue: PurchaseIssue?
    @State private var showsIssue = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ProHero(isUnlocked: purchases.isPro)
                    ProFeatureList()

                    if purchases.isPro {
                        unlockedCard
                    } else {
                        purchaseCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("pro.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
            }
            .alert("pro.error.title", isPresented: $showsIssue) {
                Button("common.ok", role: .cancel) {}
            } message: {
                if let issue {
                    Text(issue.message)
                }
            }
        }
    }

    private var purchaseCard: some View {
        VStack(spacing: 14) {
            Button {
                Task { await purchase() }
            } label: {
                HStack(spacing: 10) {
                    if purchases.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }

                    Text("pro.buy")
                    Spacer()

                    if let price = purchases.product?.displayPrice {
                        Text(price)
                            .monospacedDigit()
                    }
                }
                .font(.headline)
                .padding(.horizontal, 18)
                .padding(.vertical, 17)
                .foregroundStyle(.white)
                .background(theme.heroGradient, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(purchases.product == nil || purchases.isPurchasing)
            .opacity(purchases.product == nil || purchases.isPurchasing ? 0.55 : 1)

            if purchases.isLoading {
                ProgressView("pro.loading")
                    .font(.footnote)
            } else if purchases.product == nil {
                Text("pro.not_configured")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryLabel)
                    .multilineTextAlignment(.center)
            } else if purchases.status == .pending {
                Text("pro.pending")
                    .font(.footnote)
                    .foregroundStyle(theme.warning)
            }

            Button("pro.restore") {
                Task { await restore() }
            }
            .font(.subheadline.weight(.semibold))
            .disabled(purchases.isPurchasing)

            Text("pro.one_time_note")
                .font(.caption)
                .foregroundStyle(theme.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .background(theme.elevatedBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var unlockedCard: some View {
        Label("pro.unlocked", systemImage: "checkmark.seal.fill")
            .font(.headline)
            .foregroundStyle(theme.success)
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(theme.success.opacity(0.1), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func purchase() async {
        do {
            try await purchases.purchase()
        } catch let purchaseIssue as PurchaseIssue {
            present(purchaseIssue)
        } catch {
            present(.purchaseFailed)
        }
    }

    private func restore() async {
        do {
            try await purchases.restore()
        } catch let purchaseIssue as PurchaseIssue {
            present(purchaseIssue)
        } catch {
            present(.restoreFailed)
        }
    }

    private func present(_ purchaseIssue: PurchaseIssue) {
        issue = purchaseIssue
        showsIssue = true
    }
}

private struct ProHero: View {
    @Environment(AppTheme.self) private var theme

    let isUnlocked: Bool

    private var title: LocalizedStringKey {
        if isUnlocked {
            return "pro.hero.unlocked"
        }
        return "pro.hero.title"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isUnlocked ? "checkmark.seal.fill" : "bolt.badge.clock.fill")
                .font(.system(size: 58, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isUnlocked ? theme.success : theme.accent)

            Text(title)
                .font(.largeTitle.bold())
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)

            Text("pro.hero.message")
                .font(.body)
                .foregroundStyle(theme.secondaryLabel)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }
}

private struct ProFeatureList: View {
    var body: some View {
        VStack(spacing: 14) {
            ProFeatureRow(
                title: "pro.feature.insights.title",
                message: "pro.feature.insights.message",
                systemImage: "chart.bar.fill"
            )
            ProFeatureRow(
                title: "pro.feature.edit.title",
                message: "pro.feature.edit.message",
                systemImage: "plus.square.fill"
            )
            ProFeatureRow(
                title: "pro.feature.export.title",
                message: "pro.feature.export.message",
                systemImage: "tablecells"
            )
            ProFeatureRow(
                title: "pro.feature.paycheck.title",
                message: "pro.feature.paycheck.message",
                systemImage: "doc.text.magnifyingglass"
            )
            ProFeatureRow(
                title: "pro.feature.design.title",
                message: "pro.feature.design.message",
                systemImage: "paintpalette.fill"
            )
            ProFeatureRow(
                title: "pro.feature.reminder.title",
                message: "pro.feature.reminder.message",
                systemImage: "bell.badge.fill"
            )
            ProFeatureRow(
                title: "pro.feature.once.title",
                message: "pro.feature.once.message",
                systemImage: "infinity"
            )
        }
    }
}

private struct ProFeatureRow: View {
    @Environment(AppTheme.self) private var theme

    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(theme.accent)
                .frame(width: 40, height: 40)
                .background(theme.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.subtleBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Pro locked") {
    ProView()
        .environment(PurchaseManager.previewFree)
        .environment(AppTheme())
        .preferredColorScheme(.dark)
}

#Preview("Pro unlocked") {
    ProView()
        .environment(PurchaseManager.previewPro)
        .environment(AppTheme())
        .preferredColorScheme(.dark)
}
