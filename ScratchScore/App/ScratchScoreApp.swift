import SwiftUI

@main
struct ScratchScoreApp: App {
    @State private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
                .modelContainer(env.modelContainer)
                .tint(.ssFairway)
        }
    }
}
