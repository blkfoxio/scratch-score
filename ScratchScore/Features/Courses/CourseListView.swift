import SwiftUI
import SwiftData

struct CourseListView: View {
    @Environment(AppEnvironment.self) private var env

    @Query(filter: #Predicate<CourseModel> { $0.deletedAt == nil }, sort: \CourseModel.name)
    private var courses: [CourseModel]

    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            Group {
                if courses.isEmpty {
                    EmptyStateView(
                        systemImage: "flag.fill",
                        title: "No courses",
                        message: "Add a course with per-hole par, stroke index, and tee yardages.",
                        actionTitle: "Add Course",
                        action: { showingNew = true }
                    )
                } else {
                    List {
                        ForEach(courses) { course in
                            NavigationLink(value: course.id) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(course.name).font(.headline)
                                    Text("\(course.holeCount) holes · Par \(course.totalPar)"
                                         + (course.locationLine.isEmpty ? "" : " · \(course.locationLine)"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Courses")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let course = env.dataStore.course(id: id) {
                    CourseEditorView(course: course)
                }
            }
            .sheet(isPresented: $showingNew) {
                NewCourseSheet()
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets { env.dataStore.softDeleteCourse(courses[index]) }
    }
}

/// Minimal create flow: name + hole count. Detailed par/yardage editing happens in the editor.
private struct NewCourseSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var holeCount = 18

    var body: some View {
        NavigationStack {
            Form {
                TextField("Course name", text: $name)
                Picker("Holes", selection: $holeCount) {
                    Text("18").tag(18)
                    Text("9").tag(9)
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle("New Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        env.dataStore.createCourse(
                            name: name.trimmingCharacters(in: .whitespaces),
                            holeCount: holeCount,
                            userId: env.auth.currentUserId
                        )
                        if let uid = env.auth.currentUserId { Task { await env.sync.syncNow(userId: uid) } }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
