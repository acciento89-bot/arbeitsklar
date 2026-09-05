import SwiftUI

struct MetricCard<Value: View>: View {
    @Environment(AppTheme.self) private var theme

    private let title: LocalizedStringKey
    private let systemImage: String
    private let value: Value

    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        @ViewBuilder value: () -> Value
    ) {
        self.title = title
        self.systemImage = systemImage
        self.value = value()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 34, height: 34)
                .background(theme.accent.opacity(0.13), in: Circle())

            value
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(title)
                .font(.caption)
                .foregroundStyle(theme.secondaryLabel)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.subtleBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

