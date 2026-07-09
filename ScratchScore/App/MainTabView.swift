import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env
    let userId: UUID
    @State private var monitor = NetworkMonitor()

    var body: some View {
        TabView {
            RoundsListView(userId: userId)
                .tabItem { Label("Rounds", systemImage: "list.bullet.rectangle.portrait") }

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.line.uptrend.xyaxis") }

            CourseListView()
                .tabItem { Label("Courses", systemImage: "flag.fill") }

            SettingsView(userId: userId)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .task {
            // Clear any locally-cached data owned by a previously signed-in account
            // before syncing, so account switches on one device start clean.
            env.dataStore.purgeForeignData(currentUserId: userId)
            monitor.onBecameOnline = { Task { await env.sync.syncNow(userId: userId) } }
            monitor.start()
            await env.sync.syncNow(userId: userId)
        }
    }
}
