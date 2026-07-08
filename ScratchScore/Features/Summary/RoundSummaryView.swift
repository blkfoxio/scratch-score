import SwiftUI

struct RoundSummaryView: View {
    @Environment(AppEnvironment.self) private var env
    let round: RoundModel
    @Binding var path: [RoundRoute]

    private var course: CourseModel? { env.dataStore.course(id: round.courseId) }
    private var stats: RoundStats {
        RoundStats(round: round, parByHole: env.dataStore.parByHole(courseId: round.courseId))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                scoreHeader
                keyStats
                zoneStats
                holeGrid
            }
            .padding()
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        reopen()
                    } label: { Label("Reopen & edit", systemImage: "pencil") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
    }

    private var scoreHeader: some View {
        VStack(spacing: 6) {
            Text(round.courseName).font(.headline)
            Text("\(round.playedOn.formatted(date: .abbreviated, time: .omitted)) · \(round.format.title)")
                .font(.caption).foregroundStyle(.secondary)
            Text("\(stats.totalStrokes)")
                .font(.system(size: 60, weight: .bold, design: .rounded)).monospacedDigit()
            if stats.hasPar {
                Text(stats.toParString + " to par")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(scoreColor(total: stats.totalStrokes, par: stats.totalPar))
            }
            if round.format == .eighteen {
                HStack(spacing: 24) {
                    labeled("Front", stats.frontStrokes)
                    labeled("Back", stats.backStrokes)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func labeled(_ label: String, _ value: Int) -> some View {
        VStack { Text("\(value)").font(.title3.weight(.bold)); Text(label).font(.caption2).foregroundStyle(.secondary) }
    }

    private var keyStats: some View {
        Card {
            HStack {
                StatChip(value: "\(stats.holesPlayed)", label: "Holes")
                Divider()
                StatChip(value: "\(stats.totalPutts)", label: "Putts")
                Divider()
                StatChip(value: "\(stats.penalties)", label: "Penalties", tint: stats.penalties > 0 ? .ssBad : .primary)
            }
        }
    }

    private var zoneStats: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scoring Zone").font(.subheadline.weight(.semibold))
                HStack {
                    StatChip(value: RoundStats.percent(stats.zoneEfficiency), label: "Down in 3", tint: .ssFairway)
                    Divider()
                    StatChip(value: stats.avgShotsToZone.map { String(format: "%.1f", $0) } ?? "—", label: "Avg to zone")
                    Divider()
                    StatChip(value: stats.upDownAttempts > 0 ? "\(stats.upDownMade)/\(stats.upDownAttempts)" : "—",
                             label: "Up & down")
                }
            }
        }
    }

    private var holeGrid: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Holes").font(.subheadline.weight(.semibold))
                let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 9)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(round.format.holeNumbers, id: \.self) { number in
                        let score = round.score(forHole: number)
                        let par = course?.activeHoles.first { $0.holeNumber == number }?.par
                        VStack(spacing: 2) {
                            Text("\(number)").font(.system(size: 9)).foregroundStyle(.secondary)
                            Text(score?.total.map(String.init) ?? "–")
                                .font(.footnote.weight(.bold)).monospacedDigit()
                                .foregroundStyle(scoreColor(total: score?.total, par: par))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(.background, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    private func reopen() {
        env.dataStore.reopenRound(round)
        path.removeLast()
        path.append(.scoring(round.id))
    }
}
