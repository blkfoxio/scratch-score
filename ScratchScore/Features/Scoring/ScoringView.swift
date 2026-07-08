import SwiftUI

/// The core hole-by-hole scoring screen: a horizontal pager, one hole per page.
struct ScoringView: View {
    @Environment(AppEnvironment.self) private var env
    let round: RoundModel
    let userId: UUID
    @Binding var path: [RoundRoute]

    @State private var selectedHole: Int
    @State private var showingGrid = false
    @State private var showingFinishConfirm = false

    private let holeNumbers: [Int]

    init(round: RoundModel, userId: UUID, path: Binding<[RoundRoute]>) {
        self.round = round
        self.userId = userId
        self._path = path
        self.holeNumbers = round.format.holeNumbers
        self._selectedHole = State(initialValue: round.format.holeNumbers.first ?? 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            TabView(selection: $selectedHole) {
                ForEach(holeNumbers, id: \.self) { number in
                    if let score = round.score(forHole: number) {
                        HoleEntryView(
                            score: score,
                            par: par(number),
                            yardage: yardage(number),
                            strokeIndex: strokeIndex(number),
                            userId: userId
                        )
                        .tag(number)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            bottomBar
        }
        .navigationTitle(round.courseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingGrid = true } label: { Image(systemName: "square.grid.3x3") }
            }
        }
        .onChange(of: selectedHole) { _, _ in
            Task { await env.sync.syncNow(userId: userId) }
        }
        .onDisappear {
            Task { await env.sync.syncNow(userId: userId) }
        }
        .sheet(isPresented: $showingGrid) {
            ScorecardGridView(round: round, course: resolvedCourse) { number in
                selectedHole = number
                showingGrid = false
            }
        }
        .confirmationDialog("Finish this round?", isPresented: $showingFinishConfirm, titleVisibility: .visible) {
            Button("Finish Round") { finish() }
            Button("Keep Scoring", role: .cancel) {}
        } message: {
            Text("You can reopen it later from the summary.")
        }
    }

    private var resolvedCourse: CourseModel? { env.dataStore.course(id: round.courseId) }

    // MARK: - Top bar

    private var topBar: some View {
        let par = par(selectedHole)
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hole \(selectedHole)").font(.title2.bold())
                HStack(spacing: 10) {
                    if let par { metaLabel("Par \(par)") }
                    if let y = yardage(selectedHole) { metaLabel("\(y) yds") }
                    if let si = strokeIndex(selectedHole) { metaLabel("SI \(si)") }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Round total").font(.caption2).foregroundStyle(.secondary)
                Text("\(runningTotal)").font(.title3.weight(.bold)).monospacedDigit()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.background.secondary)
    }

    private func metaLabel(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            navButton(systemName: "chevron.left", disabled: isFirst) { goPrev() }
            if isLast {
                Button { showingFinishConfirm = true } label: {
                    Text("Finish").fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.ssFairway)
                .controlSize(.large)
            } else {
                Text("\(holeIndex + 1) of \(holeNumbers.count)")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            navButton(systemName: "chevron.right", disabled: isLast) { goNext() }
        }
        .padding()
        .background(.background.secondary)
    }

    private func navButton(systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName).font(.headline).frame(width: 52, height: 44)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(disabled)
    }

    // MARK: - Navigation helpers

    private var holeIndex: Int { holeNumbers.firstIndex(of: selectedHole) ?? 0 }
    private var isFirst: Bool { holeIndex == 0 }
    private var isLast: Bool { holeIndex == holeNumbers.count - 1 }

    private func goPrev() { if !isFirst { withAnimation { selectedHole = holeNumbers[holeIndex - 1] } } }
    private func goNext() { if !isLast { withAnimation { selectedHole = holeNumbers[holeIndex + 1] } } }

    private var runningTotal: Int {
        round.activeScores.compactMap { $0.total }.reduce(0, +)
    }

    private func finish() {
        env.dataStore.finishRound(round)
        Haptics.success()
        Task { await env.sync.syncNow(userId: userId) }
        // Replace the scoring screen with the summary.
        path.removeLast()
        path.append(.summary(round.id))
    }

    // MARK: - Course lookups

    private func par(_ number: Int) -> Int? {
        resolvedCourse?.activeHoles.first { $0.holeNumber == number }?.par
    }
    private func strokeIndex(_ number: Int) -> Int? {
        resolvedCourse?.activeHoles.first { $0.holeNumber == number }?.handicapIndex
    }
    private func yardage(_ number: Int) -> Int? {
        guard let teeId = round.teeSetId, let tee = env.dataStore.teeSet(id: teeId) else { return nil }
        return tee.yardage(forHole: number)
    }
}
