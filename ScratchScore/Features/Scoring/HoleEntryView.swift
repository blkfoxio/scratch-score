import SwiftUI

/// One hole's scoring-zone entry: Row A, Row B, the derived total (Row C), putts (Row D),
/// and the optional markers.
struct HoleEntryView: View {
    @Environment(AppEnvironment.self) private var env
    let score: HoleScoreModel
    let par: Int?
    let yardage: Int?
    let strokeIndex: Int?
    let userId: UUID

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                totalBadge

                Card {
                    VStack(spacing: 18) {
                        ScoreStepper(
                            title: "To scoring zone (A)",
                            systemImage: "scope",
                            value: bindingA,
                            range: 0...12,
                            valueTint: { _ in .primary },
                            onChange: {}
                        )
                        Divider()
                        ScoreStepper(
                            title: "In scoring zone (B)",
                            systemImage: "flag.fill",
                            value: bindingB,
                            range: 0...12,
                            valueTint: zoneTint,
                            onChange: {}
                        )
                        Text("Goal: hole out in 3 or fewer from inside 100 yds")
                            .font(.caption2).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Divider()
                        ScoreStepper(
                            title: "Putts (D)",
                            systemImage: "circle.circle",
                            value: bindingPutts,
                            range: 0...8,
                            defaultOnFirstTap: 1,
                            onChange: {}
                        )
                        Text("Putts are part of Row B — shown for stats, not added again.")
                            .font(.caption2).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                markersCard
            }
            .padding()
        }
    }

    // MARK: - Total badge (Row C)

    private var totalBadge: some View {
        VStack(spacing: 4) {
            Text("TOTAL (A + B)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(score.total.map(String.init) ?? "–")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(scoreColor(total: score.total, par: par))
                .contentTransition(.numericText())
            if let par, let total = score.total {
                Text(relativeToPar(total: total, par: par))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(scoreColor(total: total, par: par))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Markers

    private var markersCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Markers").font(.subheadline.weight(.semibold))

                HStack {
                    Label("Penalty strokes", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                    Spacer()
                    Stepper(value: penaltyBinding, in: 0...6) {
                        Text("\(score.penaltyStrokes)").monospacedDigit().frame(minWidth: 20)
                    }
                    .labelsHidden()
                    Text("\(score.penaltyStrokes)").monospacedDigit().frame(minWidth: 16)
                }

                Toggle(isOn: upDownAttemptBinding) {
                    Label("Up & down attempt", systemImage: "arrow.up.arrow.down")
                        .font(.subheadline)
                }
                .tint(.ssFairway)

                if score.upAndDownAttempted {
                    Toggle(isOn: upDownMadeBinding) {
                        Label("Up & down made", systemImage: "checkmark.circle")
                            .font(.subheadline)
                    }
                    .tint(.ssGood)
                    .padding(.leading, 28)
                }

                Toggle(isOn: longPuttBinding) {
                    Label("Putt made over 4 ft", systemImage: "figure.golf")
                        .font(.subheadline)
                }
                .tint(.ssFairway)
            }
        }
    }

    // MARK: - Bindings (write through the data store)

    private var bindingA: Binding<Int?> {
        Binding(get: { score.shotsToZone }, set: { new in env.dataStore.updateScore(score) { $0.shotsToZone = new } })
    }
    private var bindingB: Binding<Int?> {
        Binding(get: { score.shotsInZone }, set: { new in env.dataStore.updateScore(score) { $0.shotsInZone = new } })
    }
    private var bindingPutts: Binding<Int?> {
        Binding(get: { score.putts }, set: { new in env.dataStore.updateScore(score) { $0.putts = new } })
    }
    private var penaltyBinding: Binding<Int> {
        Binding(get: { score.penaltyStrokes }, set: { new in env.dataStore.updateScore(score) { $0.penaltyStrokes = new } })
    }
    private var upDownAttemptBinding: Binding<Bool> {
        Binding(get: { score.upAndDownAttempted }, set: { new in
            env.dataStore.updateScore(score) { s in
                s.upAndDownAttempted = new
                if !new { s.upAndDownMade = false }
            }
        })
    }
    private var upDownMadeBinding: Binding<Bool> {
        Binding(get: { score.upAndDownMade }, set: { new in env.dataStore.updateScore(score) { $0.upAndDownMade = new } })
    }
    private var longPuttBinding: Binding<Bool> {
        Binding(get: { score.longPuttMade }, set: { new in env.dataStore.updateScore(score) { $0.longPuttMade = new } })
    }

    private func zoneTint(_ value: Int?) -> Color {
        guard let value else { return .primary }
        return value <= 3 ? .ssGood : .ssBad
    }

    private func relativeToPar(total: Int, par: Int) -> String {
        let diff = total - par
        switch diff {
        case 0: return "Par"
        case -1: return "Birdie"
        case ..<(-1): return "\(abs(diff)) under"
        case 1: return "Bogey"
        default: return "+\(diff)"
        }
    }
}
