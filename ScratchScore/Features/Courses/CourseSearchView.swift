import SwiftUI

/// Search golfcourseapi.com and download a course (with par, stroke index, tees, and
/// yardages) into your own course list. Imported courses sync and work offline.
struct CourseSearchView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [APICourse] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var importedIds: Set<Int> = []
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView("Searching…").frame(maxHeight: .infinity)
                } else if let errorMessage {
                    EmptyStateView(systemImage: "exclamationmark.triangle",
                                   title: "Search failed", message: errorMessage,
                                   actionTitle: "Try Again", action: runSearch)
                } else if results.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: hasSearched ? "No courses found" : "Search for a course",
                        message: hasSearched
                            ? "Try the club name, or add the city."
                            : "Find a course by name and download its scorecard — par, stroke index, tees, and yardages."
                    )
                } else {
                    List(results) { course in
                        CourseResultRow(
                            course: course,
                            isImported: importedIds.contains(course.id) || env.dataStore.importedCourse(externalId: course.id) != nil,
                            onDownload: { download(course) }
                        )
                    }
                }
            }
            .navigationTitle("Find Course")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Course or club name")
            .onSubmit(of: .search, runSearch)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        hasSearched = true
        Task {
            defer { isSearching = false }
            do {
                results = try await env.golfAPI.search(trimmed)
            } catch {
                results = []
                errorMessage = error.localizedDescription
            }
        }
    }

    private func download(_ course: APICourse) {
        env.dataStore.importCourse(course, userId: env.auth.currentUserId)
        importedIds.insert(course.id)
        Haptics.success()
        if let uid = env.auth.currentUserId { Task { await env.sync.syncNow(userId: uid) } }
    }
}

private struct CourseResultRow: View {
    let course: APICourse
    let isImported: Bool
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(course.displayName).font(.subheadline.weight(.semibold))
                if let location = locationLine {
                    Text(location).font(.caption).foregroundStyle(.secondary)
                }
                if let summary = teeSummary {
                    Text(summary).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isImported {
                Label("Added", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly).font(.title3).foregroundStyle(.ssGood)
            } else {
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle").font(.title3)
                }
                .buttonStyle(.plain).foregroundStyle(.ssFairway)
            }
        }
        .padding(.vertical, 2)
    }

    private var locationLine: String? {
        let parts = [course.location?.city, course.location?.state].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private var teeSummary: String? {
        guard let tee = course.referenceTee else { return nil }
        var parts: [String] = []
        let holes = tee.numberOfHoles ?? tee.holes.count
        if holes > 0 { parts.append("\(holes) holes") }
        if let par = tee.parTotal { parts.append("Par \(par)") }
        let teeCount = course.allTees.count
        if teeCount > 0 { parts.append("\(teeCount) tee\(teeCount == 1 ? "" : "s")") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
