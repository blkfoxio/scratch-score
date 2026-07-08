import SwiftUI
import SwiftData

enum RoundRoute: Hashable {
    case scoring(UUID)
    case summary(UUID)
}

struct RoundsListView: View {
    @Environment(AppEnvironment.self) private var env
    let userId: UUID

    @Query(sort: [SortDescriptor(\RoundModel.playedOn, order: .reverse),
                  SortDescriptor(\RoundModel.startedAt, order: .reverse)])
    private var allRounds: [RoundModel]

    @Query private var allCourses: [CourseModel]

    private var rounds: [RoundModel] { allRounds.filter { !$0.isTombstoned } }
    private var courses: [CourseModel] { allCourses.filter { !$0.isTombstoned } }

    @State private var path: [RoundRoute] = []
    @State private var showingNewRound = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if rounds.isEmpty {
                    EmptyStateView(
                        systemImage: "figure.golf",
                        title: "No rounds yet",
                        message: courses.isEmpty
                            ? "Add a course first, then start your first round."
                            : "Tap + to start tracking a round with the scoring-zone method.",
                        actionTitle: courses.isEmpty ? nil : "Start a Round",
                        action: courses.isEmpty ? nil : { showingNewRound = true }
                    )
                } else {
                    List {
                        ForEach(rounds) { round in
                            Button { open(round) } label: { RoundRow(round: round, store: env.dataStore) }
                                .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteRounds)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Rounds")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewRound = true } label: { Image(systemName: "plus") }
                        .disabled(courses.isEmpty)
                }
            }
            .sheet(isPresented: $showingNewRound) {
                NewRoundSetupView(userId: userId) { round in
                    path.append(.scoring(round.id))
                }
            }
            .navigationDestination(for: RoundRoute.self) { route in
                switch route {
                case let .scoring(id):
                    if let round = env.dataStore.round(id: id) {
                        ScoringView(round: round, userId: userId, path: $path)
                    }
                case let .summary(id):
                    if let round = env.dataStore.round(id: id) {
                        RoundSummaryView(round: round, path: $path)
                    }
                }
            }
        }
    }

    private func open(_ round: RoundModel) {
        path.append(round.status == .completed ? .summary(round.id) : .scoring(round.id))
    }

    private func deleteRounds(_ offsets: IndexSet) {
        for index in offsets { env.dataStore.softDeleteRound(rounds[index]) }
        Task { await env.sync.syncNow(userId: userId) }
    }
}

private struct RoundRow: View {
    let round: RoundModel
    let store: DataStore

    var body: some View {
        let stats = RoundStats(round: round, parByHole: store.parByHole(courseId: round.courseId))
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(round.courseName).font(.headline)
                Text("\(round.playedOn.formatted(date: .abbreviated, time: .omitted)) · \(round.format.title)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if round.status == .inProgress {
                    Text("In progress").font(.caption.weight(.semibold)).foregroundStyle(.ssWarn)
                    Text("\(stats.holesPlayed)/\(stats.holesInFormat) holes")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("\(stats.totalStrokes)").font(.title3.weight(.bold))
                    Text(stats.hasPar ? stats.toParString : "\(stats.holesPlayed) holes")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
