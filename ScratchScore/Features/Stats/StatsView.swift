import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(AppEnvironment.self) private var env

    @Query(sort: [SortDescriptor(\RoundModel.playedOn, order: .forward)])
    private var allRounds: [RoundModel]

    private var rounds: [RoundModel] {
        allRounds.filter { !$0.isTombstoned && $0.status == .completed }
    }

    private var series: [RoundStatPoint] {
        rounds.map { round in
            RoundStatPoint(
                round: round,
                stats: RoundStats(round: round, parByHole: env.dataStore.parByHole(courseId: round.courseId))
            )
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if series.isEmpty {
                    EmptyStateView(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "No stats yet",
                        message: "Finish a round to see your scoring-zone trends here."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            averagesCard
                            trendCard(title: "Total score", tint: .ssFairway) { $0.stats.totalStrokes }
                            trendCard(title: "Putts", tint: .blue) { $0.stats.totalPutts }
                            zoneTrendCard
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }

    private var averagesCard: some View {
        let count = Double(series.count)
        let avgScore = series.map { Double($0.stats.totalStrokes) }.reduce(0, +) / count
        let avgPutts = series.map { Double($0.stats.totalPutts) }.reduce(0, +) / count
        let zoneRates = series.compactMap { $0.stats.zoneEfficiency }
        let avgZone = zoneRates.isEmpty ? nil : zoneRates.reduce(0, +) / Double(zoneRates.count)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Averages · \(series.count) rounds").font(.subheadline.weight(.semibold))
                HStack {
                    StatChip(value: String(format: "%.1f", avgScore), label: "Score")
                    Divider()
                    StatChip(value: String(format: "%.1f", avgPutts), label: "Putts")
                    Divider()
                    StatChip(value: RoundStats.percent(avgZone), label: "Down in 3", tint: .ssFairway)
                }
            }
        }
    }

    private func trendCard(title: String, tint: Color, value: @escaping (RoundStatPoint) -> Int) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.subheadline.weight(.semibold))
                Chart(series) { point in
                    LineMark(x: .value("Date", point.date), y: .value(title, value(point)))
                        .foregroundStyle(tint)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", point.date), y: .value(title, value(point)))
                        .foregroundStyle(tint)
                }
                .frame(height: 160)
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
            }
        }
    }

    private var zoneTrendCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Down-in-3 %").font(.subheadline.weight(.semibold))
                Chart(series) { point in
                    if let rate = point.stats.zoneEfficiency {
                        BarMark(x: .value("Date", point.date, unit: .day),
                                y: .value("Rate", rate * 100))
                            .foregroundStyle(.ssFairway)
                    }
                }
                .frame(height: 160)
                .chartYScale(domain: 0...100)
            }
        }
    }
}

struct RoundStatPoint: Identifiable {
    let round: RoundModel
    let stats: RoundStats
    var id: UUID { round.id }
    var date: Date { round.playedOn }
}
