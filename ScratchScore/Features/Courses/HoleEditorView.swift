import SwiftUI

/// Edit par and stroke index for every hole on the course.
struct HoleEditorView: View {
    @Environment(AppEnvironment.self) private var env
    let course: CourseModel

    var body: some View {
        Form {
            ForEach(course.activeHoles) { hole in
                HoleRow(hole: hole) { env.dataStore.touch(course) }
            }
        }
        .navigationTitle("Holes")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            if let uid = env.auth.currentUserId { Task { await env.sync.syncNow(userId: uid) } }
        }
    }
}

private struct HoleRow: View {
    @Bindable var hole: HoleModel
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text("Hole \(hole.holeNumber)").font(.subheadline.weight(.medium)).frame(width: 70, alignment: .leading)

            Stepper(value: $hole.par, in: 3...6) {
                Text("Par \(hole.par)").monospacedDigit()
            }
            .onChange(of: hole.par) { _, _ in hole.markDirty(); onEdit() }

            HStack(spacing: 4) {
                Text("SI").font(.caption).foregroundStyle(.secondary)
                TextField("–", value: strokeIndexBinding, format: .number)
                    .keyboardType(.numberPad)
                    .frame(width: 34)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var strokeIndexBinding: Binding<Int?> {
        Binding(get: { hole.handicapIndex }, set: { hole.handicapIndex = $0; hole.markDirty(); onEdit() })
    }
}
