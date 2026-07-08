import SwiftUI

struct CourseEditorView: View {
    @Environment(AppEnvironment.self) private var env
    @Bindable var course: CourseModel

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $course.name)
                TextField("City", text: Binding($course.city, replacingNilWith: ""))
                TextField("Region / State", text: Binding($course.region, replacingNilWith: ""))
            }

            Section("Holes") {
                NavigationLink {
                    HoleEditorView(course: course)
                } label: {
                    LabeledContent("Par & stroke index", value: "Par \(course.totalPar)")
                }
            }

            Section("Tees") {
                ForEach(course.activeTeeSets) { tee in
                    NavigationLink {
                        TeeSetEditorView(course: course, teeSet: tee)
                    } label: {
                        LabeledContent(tee.name, value: tee.totalYardage.map { "\($0) yds" } ?? "Set yardages")
                    }
                }
                Button {
                    env.dataStore.addTeeSet(to: course, name: "New Tee", userId: env.auth.currentUserId)
                } label: {
                    Label("Add tee set", systemImage: "plus")
                }
            }
        }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: course.name) { _, _ in env.dataStore.touch(course) }
        .onChange(of: course.city) { _, _ in env.dataStore.touch(course) }
        .onChange(of: course.region) { _, _ in env.dataStore.touch(course) }
        .onDisappear { syncIfPossible() }
    }

    private func syncIfPossible() {
        if let uid = env.auth.currentUserId { Task { await env.sync.syncNow(userId: uid) } }
    }
}

extension Binding where Value == String {
    /// Bridges an optional String model property to a non-optional TextField binding.
    init(_ source: Binding<String?>, replacingNilWith placeholder: String) {
        self.init(
            get: { source.wrappedValue ?? placeholder },
            set: { source.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}
