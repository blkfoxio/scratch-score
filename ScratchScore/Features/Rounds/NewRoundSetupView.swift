import SwiftUI
import SwiftData

struct NewRoundSetupView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let userId: UUID
    let onStart: (RoundModel) -> Void

    @Query(filter: #Predicate<CourseModel> { $0.deletedAt == nil }, sort: \CourseModel.name)
    private var courses: [CourseModel]

    @State private var selectedCourseId: UUID?
    @State private var selectedTeeId: UUID?
    @State private var format: RoundFormat = .eighteen
    @State private var playedOn = Date()

    private var selectedCourse: CourseModel? {
        courses.first { $0.id == selectedCourseId }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Course") {
                    Picker("Course", selection: $selectedCourseId) {
                        ForEach(courses) { Text($0.name).tag(Optional($0.id)) }
                    }
                    if let course = selectedCourse, !course.activeTeeSets.isEmpty {
                        Picker("Tees", selection: $selectedTeeId) {
                            ForEach(course.activeTeeSets) { tee in
                                Text(teeLabel(tee)).tag(Optional(tee.id))
                            }
                        }
                    }
                }

                Section("Format") {
                    Picker("Holes", selection: $format) {
                        ForEach(availableFormats) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Date", selection: $playedOn, displayedComponents: .date)
                }

                Section {
                    Button {
                        startRound()
                    } label: {
                        Text("Start Round").frame(maxWidth: .infinity).fontWeight(.semibold)
                    }
                    .disabled(selectedCourse == nil)
                }
            }
            .navigationTitle("New Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: preselect)
            .onChange(of: selectedCourseId) { _, _ in
                selectedTeeId = selectedCourse?.activeTeeSets.first?.id
                if selectedCourse?.holeCount == 9 { format = .frontNine }
            }
        }
    }

    private var availableFormats: [RoundFormat] {
        (selectedCourse?.holeCount ?? 18) == 9 ? [.frontNine] : RoundFormat.allCases
    }

    private func teeLabel(_ tee: TeeSetModel) -> String {
        var parts = [tee.name]
        if let yards = tee.totalYardage { parts.append("\(yards) yds") }
        return parts.joined(separator: " · ")
    }

    private func preselect() {
        if selectedCourseId == nil { selectedCourseId = courses.first?.id }
        selectedTeeId = selectedCourse?.activeTeeSets.first?.id
    }

    private func startRound() {
        guard let course = selectedCourse else { return }
        let tee = course.activeTeeSets.first { $0.id == selectedTeeId }
        let round = env.dataStore.createRound(
            course: course, teeSet: tee, format: format, playedOn: playedOn, userId: userId
        )
        Task { await env.sync.syncNow(userId: userId) }
        dismiss()
        onStart(round)
    }
}
