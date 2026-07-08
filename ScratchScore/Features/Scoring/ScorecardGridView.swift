import SwiftUI

/// A read-only grid of every hole in the round for quick jumping. Tapping a hole
/// dismisses and navigates the pager there.
struct ScorecardGridView: View {
    @Environment(\.dismiss) private var dismiss
    let round: RoundModel
    let course: CourseModel?
    let onSelect: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(round.format.holeNumbers, id: \.self) { number in
                        cell(number)
                    }
                }
                .padding()
            }
            .navigationTitle("Scorecard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func cell(_ number: Int) -> some View {
        let score = round.score(forHole: number)
        let par = course?.activeHoles.first { $0.holeNumber == number }?.par
        return Button {
            onSelect(number)
        } label: {
            VStack(spacing: 4) {
                Text("H\(number)").font(.caption2).foregroundStyle(.secondary)
                Text(score?.total.map(String.init) ?? "–")
                    .font(.title3.weight(.bold)).monospacedDigit()
                    .foregroundStyle(scoreColor(total: score?.total, par: par))
                if let par { Text("Par \(par)").font(.caption2).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
