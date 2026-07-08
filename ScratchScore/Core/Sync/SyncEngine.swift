import Foundation
import Observation
import Supabase

/// Reconciles the local SwiftData store with Supabase.
///
/// Strategy: push all `.pendingPush` rows (parents → children so FKs resolve), then
/// pull rows changed since each table's high-water mark (parents → children), applying
/// last-write-wins. Soft-deletes propagate as tombstones. Everything is a no-op when
/// the backend is unconfigured or no user is signed in.
@MainActor
@Observable
final class SyncEngine {
    enum Status: Equatable {
        case idle, syncing, error(String)
    }

    private(set) var status: Status = .idle
    private(set) var lastSyncedAt: Date?

    private let supabase: SupabaseClient
    private let store: DataStore
    private var isRunning = false

    init(supabase: SupabaseClient, store: DataStore) {
        self.supabase = supabase
        self.store = store
    }

    private let epoch = "1970-01-01T00:00:00.000Z"

    // MARK: - Public entry points

    func syncNow(userId: UUID) async {
        guard AppConfig.isBackendConfigured, !isRunning else { return }
        isRunning = true
        status = .syncing
        defer { isRunning = false }
        do {
            try await push(userId: userId)
            try await pull(userId: userId)
            store.save()
            lastSyncedAt = Date()
            status = .idle
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    // MARK: - Push (local → remote), parents before children

    private func push(userId: UUID) async throws {
        let profiles = store.pendingProfiles()
        try await upsert("profiles", profiles.map { $0.toDTO() }, source: profiles)

        let courses = store.pendingCourses()
        courses.forEach { stamp($0, userId) }
        try await upsert("courses", courses.map { $0.toDTO(userId: userId) }, source: courses)

        let tees = store.pendingTeeSets()
        try await upsert("tee_sets", tees.compactMap { t -> TeeSetDTO? in
            guard let cid = t.course?.id else { return nil }
            stamp(t, userId); return t.toDTO(userId: userId, courseId: cid)
        }, source: tees)

        let holes = store.pendingHoles()
        try await upsert("holes", holes.compactMap { h -> HoleDTO? in
            guard let cid = h.course?.id else { return nil }
            stamp(h, userId); return h.toDTO(userId: userId, courseId: cid)
        }, source: holes)

        let yardages = store.pendingYardages()
        try await upsert("tee_hole_yardages", yardages.compactMap { y -> TeeHoleYardageDTO? in
            guard let tid = y.teeSet?.id else { return nil }
            stamp(y, userId); return y.toDTO(userId: userId, teeSetId: tid)
        }, source: yardages)

        let rounds = store.pendingRounds()
        rounds.forEach { stamp($0, userId) }
        try await upsert("rounds", rounds.map { $0.toDTO(userId: userId) }, source: rounds)

        let scores = store.pendingHoleScores()
        try await upsert("hole_scores", scores.compactMap { s -> HoleScoreDTO? in
            guard let rid = s.round?.id else { return nil }
            stamp(s, userId); return s.toDTO(userId: userId, roundId: rid)
        }, source: scores)
    }

    private func stamp(_ item: any Syncable, _ userId: UUID) {
        if let c = item as? CourseModel { c.userId = userId }
        else if let t = item as? TeeSetModel { t.userId = userId }
        else if let h = item as? HoleModel { h.userId = userId }
        else if let y = item as? TeeHoleYardageModel { y.userId = userId }
        else if let r = item as? RoundModel { r.userId = userId }
        else if let s = item as? HoleScoreModel { s.userId = userId }
    }

    private func upsert<D: Encodable>(_ table: String, _ dtos: [D], source: [any Syncable]) async throws {
        guard !dtos.isEmpty else { return }
        try await supabase.from(table).upsert(dtos, onConflict: "id").execute()
        store.markSynced(source)
    }

    // MARK: - Pull (remote → local), parents before children

    private func pull(userId: UUID) async throws {
        let state = SyncState(userId: userId)

        try await pullTable(.profiles, state) { (rows: [ProfileDTO]) in
            rows.forEach(self.store.applyProfile)
        }
        try await pullTable(.courses, state) { (rows: [CourseDTO]) in
            rows.forEach(self.store.applyCourse)
        }
        try await pullTable(.tee_sets, state) { (rows: [TeeSetDTO]) in
            rows.forEach(self.store.applyTeeSet)
        }
        try await pullTable(.holes, state) { (rows: [HoleDTO]) in
            rows.forEach(self.store.applyHole)
        }
        try await pullTable(.tee_hole_yardages, state) { (rows: [TeeHoleYardageDTO]) in
            rows.forEach(self.store.applyYardage)
        }
        try await pullTable(.rounds, state) { (rows: [RoundDTO]) in
            rows.forEach(self.store.applyRound)
        }
        try await pullTable(.hole_scores, state) { (rows: [HoleScoreDTO]) in
            rows.forEach(self.store.applyHoleScore)
        }
    }

    private func pullTable<D: Decodable>(
        _ table: SyncState.Table,
        _ state: SyncState,
        apply: ([D]) -> Void
    ) async throws {
        let since = ISO8601.string(from: state.lastPulled(table)) ?? epoch
        let rows: [D] = try await supabase
            .from(table.rawValue)
            .select()
            .gt("updated_at", value: since)
            .order("updated_at", ascending: true)
            .execute()
            .value
        apply(rows)
        state.setLastPulled(table, Date())
    }
}
