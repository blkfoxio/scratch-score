import Foundation
import SwiftData

/// Repository over the SwiftData `ModelContext`. All UI reads/writes go through the
/// local store (offline-first); the `SyncEngine` reconciles with Supabase separately.
@MainActor
final class DataStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save() {
        guard context.hasChanges else { return }
        do { try context.save() } catch { print("DataStore save error: \(error)") }
    }

    // MARK: - Generic fetch by id

    private func fetchOne<T: PersistentModel>(_ type: T.Type, id: UUID, predicate: Predicate<T>) -> T? {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func course(id: UUID) -> CourseModel? {
        fetchOne(CourseModel.self, id: id, predicate: #Predicate { $0.id == id })
    }
    func teeSet(id: UUID) -> TeeSetModel? {
        fetchOne(TeeSetModel.self, id: id, predicate: #Predicate { $0.id == id })
    }
    func hole(id: UUID) -> HoleModel? {
        fetchOne(HoleModel.self, id: id, predicate: #Predicate { $0.id == id })
    }
    func yardage(id: UUID) -> TeeHoleYardageModel? {
        fetchOne(TeeHoleYardageModel.self, id: id, predicate: #Predicate { $0.id == id })
    }
    func round(id: UUID) -> RoundModel? {
        fetchOne(RoundModel.self, id: id, predicate: #Predicate { $0.id == id })
    }
    func holeScore(id: UUID) -> HoleScoreModel? {
        fetchOne(HoleScoreModel.self, id: id, predicate: #Predicate { $0.id == id })
    }
    func profile(id: UUID) -> ProfileModel? {
        fetchOne(ProfileModel.self, id: id, predicate: #Predicate { $0.id == id })
    }

    // MARK: - List fetches (active = not soft-deleted)

    func allCourses() -> [CourseModel] {
        let descriptor = FetchDescriptor<CourseModel>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor))?.filter { !$0.isTombstoned } ?? []
    }

    func allRounds() -> [RoundModel] {
        let descriptor = FetchDescriptor<RoundModel>(
            sortBy: [SortDescriptor(\.playedOn, order: .reverse), SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.filter { !$0.isTombstoned } ?? []
    }

    func completedRounds() -> [RoundModel] {
        allRounds().filter { $0.status == .completed }
    }

    /// Hole number → par for a course, used to compute score-relative-to-par.
    func parByHole(courseId: UUID) -> [Int: Int] {
        guard let course = course(id: courseId) else { return [:] }
        return Dictionary(uniqueKeysWithValues: course.activeHoles.map { ($0.holeNumber, $0.par) })
    }

    // MARK: - Pending push gatherers

    private func pending<T>(_ type: T.Type) -> [T] where T: PersistentModel & Syncable {
        let all = (try? context.fetch(FetchDescriptor<T>())) ?? []
        return all.filter { $0.syncStatus == .pendingPush }
    }

    func pendingProfiles() -> [ProfileModel] { pending(ProfileModel.self) }
    func pendingCourses() -> [CourseModel] { pending(CourseModel.self) }
    func pendingTeeSets() -> [TeeSetModel] { pending(TeeSetModel.self) }
    func pendingHoles() -> [HoleModel] { pending(HoleModel.self) }
    func pendingYardages() -> [TeeHoleYardageModel] { pending(TeeHoleYardageModel.self) }
    func pendingRounds() -> [RoundModel] { pending(RoundModel.self) }
    func pendingHoleScores() -> [HoleScoreModel] { pending(HoleScoreModel.self) }

    func markSynced(_ items: [any Syncable]) {
        for item in items { item.syncStatus = .synced }
        save()
    }

    // MARK: - Wipe (account deletion / sign-out reset)

    func wipeAll() {
        for type in AppModelContainer.schemaTypes {
            try? context.delete(model: type)
        }
        save()
    }

    /// Removes any locally-cached rows that belong to a *different* user. Guards against
    /// cross-account contamination when switching accounts on the same device: without
    /// this, pushing another user's rows fails Postgres RLS. Rows with no owner yet
    /// (`userId == nil`) are treated as the current user's freshly-created data and kept.
    func purgeForeignData(currentUserId: UUID) {
        var changed = false
        func purge<T: PersistentModel>(_ type: T.Type, isForeign: (T) -> Bool) {
            let items = (try? context.fetch(FetchDescriptor<T>())) ?? []
            for item in items where isForeign(item) {
                context.delete(item)
                changed = true
            }
        }
        let foreign: (UUID?) -> Bool = { $0 != nil && $0 != currentUserId }
        // Delete parents first; SwiftData cascade rules clean up their children.
        purge(CourseModel.self) { foreign($0.userId) }
        purge(RoundModel.self) { foreign($0.userId) }
        purge(TeeSetModel.self) { foreign($0.userId) }
        purge(HoleModel.self) { foreign($0.userId) }
        purge(TeeHoleYardageModel.self) { foreign($0.userId) }
        purge(HoleScoreModel.self) { foreign($0.userId) }
        purge(ProfileModel.self) { $0.id != currentUserId }
        if changed { save() }
    }
}
