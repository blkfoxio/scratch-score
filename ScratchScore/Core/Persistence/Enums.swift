import Foundation

/// Local sync state for a row. Drives the push queue.
enum SyncStatus: String, Codable, Sendable {
    case synced
    case pendingPush
    case conflict
}

/// Lifecycle of a round.
enum RoundStatus: String, Codable, Sendable, CaseIterable {
    case inProgress = "in_progress"
    case completed
    case abandoned
}

/// Which holes a round covers. The scoring method is identical across formats;
/// only the hole range changes.
enum RoundFormat: String, Codable, Sendable, CaseIterable, Identifiable {
    case eighteen
    case frontNine
    case backNine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eighteen: return "18 Holes"
        case .frontNine: return "Front 9"
        case .backNine: return "Back 9"
        }
    }

    /// 1-based hole numbers this format plays.
    var holeNumbers: [Int] {
        switch self {
        case .eighteen: return Array(1...18)
        case .frontNine: return Array(1...9)
        case .backNine: return Array(10...18)
        }
    }
}
