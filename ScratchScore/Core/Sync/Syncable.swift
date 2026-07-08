import Foundation

/// Common sync bookkeeping shared by every locally-persisted, cloud-backed model.
/// Local and remote rows share the same client-generated `id` (UUID) so identity
/// is stable across pulls.
protocol Syncable: AnyObject {
    var id: UUID { get }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
    var syncStatusRaw: String { get set }
}

extension Syncable {
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .synced }
        set { syncStatusRaw = newValue.rawValue }
    }

    /// Soft-deleted tombstone. Named to avoid colliding with SwiftData's built-in
    /// `PersistentModel.isDeleted` (which means "removed from the context").
    var isTombstoned: Bool { deletedAt != nil }

    /// Marks the row dirty for the next push. Call inside every local mutation.
    func markDirty(now: Date = Date()) {
        updatedAt = now
        syncStatus = .pendingPush
    }

    /// Soft-deletes the row so the tombstone can propagate to other devices.
    func softDelete(now: Date = Date()) {
        deletedAt = now
        markDirty(now: now)
    }
}
