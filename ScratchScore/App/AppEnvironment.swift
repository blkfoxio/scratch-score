import Foundation
import SwiftData
import Supabase

/// Root dependency container. Built once at launch and injected into the view tree.
@MainActor
@Observable
final class AppEnvironment {
    let isBackendConfigured: Bool
    let modelContainer: ModelContainer
    let supabase: SupabaseClient
    let auth: AuthManager
    let dataStore: DataStore
    let sync: SyncEngine
    let golfAPI = GolfCourseAPI()

    init(inMemory: Bool = false) {
        self.isBackendConfigured = AppConfig.isBackendConfigured
        let container = AppModelContainer.make(inMemory: inMemory)
        self.modelContainer = container

        let client = SupabaseClientProvider.make()
        self.supabase = client
        self.auth = AuthManager(supabase: client)

        let store = DataStore(context: container.mainContext)
        self.dataStore = store
        self.sync = SyncEngine(supabase: client, store: store)
    }

    var modelContext: ModelContext { modelContainer.mainContext }
}
