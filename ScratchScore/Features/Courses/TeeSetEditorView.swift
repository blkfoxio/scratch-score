import SwiftUI

struct TeeSetEditorView: View {
    @Environment(AppEnvironment.self) private var env
    let course: CourseModel
    @Bindable var teeSet: TeeSetModel

    var body: some View {
        Form {
            Section("Tee") {
                TextField("Name", text: $teeSet.name)
                    .onChange(of: teeSet.name) { _, _ in teeSet.markDirty() }
                HStack {
                    Text("Rating")
                    Spacer()
                    TextField("72.0", value: $teeSet.rating, format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                        .onChange(of: teeSet.rating) { _, _ in teeSet.markDirty() }
                }
                HStack {
                    Text("Slope")
                    Spacer()
                    TextField("113", value: $teeSet.slope, format: .number)
                        .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80)
                        .onChange(of: teeSet.slope) { _, _ in teeSet.markDirty() }
                }
            }

            Section("Yardages") {
                ForEach(course.activeHoles) { hole in
                    HStack {
                        Text("Hole \(hole.holeNumber)").frame(width: 70, alignment: .leading)
                        Text("Par \(hole.par)").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        TextField("yds", value: yardageBinding(hole.holeNumber), format: .number)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 70)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                if let total = teeSet.totalYardage {
                    LabeledContent("Total", value: "\(total) yds").font(.subheadline.weight(.semibold))
                }
            }
        }
        .navigationTitle(teeSet.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            if let uid = env.auth.currentUserId { Task { await env.sync.syncNow(userId: uid) } }
        }
    }

    private func yardageBinding(_ hole: Int) -> Binding<Int?> {
        Binding(
            get: { teeSet.yardage(forHole: hole) },
            set: { env.dataStore.setYardage($0, hole: hole, teeSet: teeSet, userId: env.auth.currentUserId) }
        )
    }
}
