import Foundation
import SwiftData

enum AppModelContainer {
    /// All persisted model types, in one place so the schema stays in sync.
    static let schemaTypes: [any PersistentModel.Type] = [
        CourseModel.self,
        TeeSetModel.self,
        HoleModel.self,
        TeeHoleYardageModel.self,
        RoundModel.self,
        HoleScoreModel.self,
        ProfileModel.self
    ]

    static func make(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(schemaTypes)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
