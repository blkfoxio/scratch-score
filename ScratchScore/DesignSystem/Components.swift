import SwiftUI

/// A rounded surface used throughout the app.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.Metrics.cardPadding
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
    }
}

/// Filled primary action button.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Metrics.controlHeight)
            .foregroundStyle(.white)
            .background(Color.ssFairway.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!isEnabled || isLoading)
    }
}

/// A compact labeled statistic used in summaries and lists.
struct StatChip: View {
    let value: String
    let label: String
    var tint: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.bold)).foregroundStyle(tint)
            Text(label).font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Empty-state placeholder.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(.ssFairway)
            }
        }
    }
}

/// Color for a score value relative to par (birdie/par/bogey coloring).
func scoreColor(total: Int?, par: Int?) -> Color {
    guard let total, let par else { return .primary }
    let diff = total - par
    switch diff {
    case ..<0: return .ssGood
    case 0: return .primary
    case 1: return .ssWarn
    default: return .ssBad
    }
}
