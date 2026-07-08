import Foundation

/// Persists per-table "last pulled" high-water marks so pulls are incremental.
/// Scoped per user so switching accounts doesn't leak cursors.
struct SyncState {
    enum Table: String, CaseIterable {
        case profiles, courses, tee_sets, holes, tee_hole_yardages, rounds, hole_scores
    }

    private let defaults = UserDefaults.standard
    private let userId: UUID

    init(userId: UUID) { self.userId = userId }

    private func key(_ table: Table) -> String {
        "sync.lastPulled.\(userId.uuidString).\(table.rawValue)"
    }

    func lastPulled(_ table: Table) -> Date? {
        let ts = defaults.double(forKey: key(table))
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    func setLastPulled(_ table: Table, _ date: Date) {
        defaults.set(date.timeIntervalSince1970, forKey: key(table))
    }

    func reset() {
        for table in Table.allCases { defaults.removeObject(forKey: key(table)) }
    }
}
