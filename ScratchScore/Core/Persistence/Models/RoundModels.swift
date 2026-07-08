import Foundation
import SwiftData

@Model
final class RoundModel: Syncable {
    @Attribute(.unique) var id: UUID
    var userId: UUID?
    var courseId: UUID
    var teeSetId: UUID?
    var courseName: String            // denormalized snapshot for fast list rendering
    var playedOn: Date
    var startedAt: Date
    var finishedAt: Date?
    var statusRaw: String
    var formatRaw: String
    var notes: String?
    var updatedAt: Date
    var deletedAt: Date?
    var syncStatusRaw: String

    @Relationship(deleteRule: .cascade, inverse: \HoleScoreModel.round)
    var holeScores: [HoleScoreModel] = []

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        courseId: UUID,
        teeSetId: UUID? = nil,
        courseName: String,
        playedOn: Date = Date(),
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        status: RoundStatus = .inProgress,
        format: RoundFormat = .eighteen,
        notes: String? = nil,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        syncStatusRaw: String = SyncStatus.pendingPush.rawValue
    ) {
        self.id = id
        self.userId = userId
        self.courseId = courseId
        self.teeSetId = teeSetId
        self.courseName = courseName
        self.playedOn = playedOn
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.statusRaw = status.rawValue
        self.formatRaw = format.rawValue
        self.notes = notes
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.syncStatusRaw = syncStatusRaw
    }

    var status: RoundStatus {
        get { RoundStatus(rawValue: statusRaw) ?? .inProgress }
        set { statusRaw = newValue.rawValue }
    }

    var format: RoundFormat {
        get { RoundFormat(rawValue: formatRaw) ?? .eighteen }
        set { formatRaw = newValue.rawValue }
    }

    var activeScores: [HoleScoreModel] {
        holeScores.filter { !$0.isTombstoned }.sorted { $0.holeNumber < $1.holeNumber }
    }

    func score(forHole holeNumber: Int) -> HoleScoreModel? {
        holeScores.first { $0.holeNumber == holeNumber && !$0.isTombstoned }
    }
}

@Model
final class HoleScoreModel: Syncable {
    @Attribute(.unique) var id: UUID
    var userId: UUID?
    var holeNumber: Int
    /// Row A — shots to enter the scoring zone (inside 100 yds).
    var shotsToZone: Int?
    /// Row B — shots from the scoring zone to holed out (goal ≤ 3). Includes putts.
    var shotsInZone: Int?
    /// Row D — total putts on the hole. A *breakdown* of Row B, never re-added into the total.
    var putts: Int?
    var penaltyStrokes: Int
    var upAndDownAttempted: Bool
    var upAndDownMade: Bool
    var longPuttMade: Bool           // putt made over 4 ft
    var updatedAt: Date
    var deletedAt: Date?
    var syncStatusRaw: String

    var round: RoundModel?

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        holeNumber: Int,
        shotsToZone: Int? = nil,
        shotsInZone: Int? = nil,
        putts: Int? = nil,
        penaltyStrokes: Int = 0,
        upAndDownAttempted: Bool = false,
        upAndDownMade: Bool = false,
        longPuttMade: Bool = false,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        syncStatusRaw: String = SyncStatus.pendingPush.rawValue,
        round: RoundModel? = nil
    ) {
        self.id = id
        self.userId = userId
        self.holeNumber = holeNumber
        self.shotsToZone = shotsToZone
        self.shotsInZone = shotsInZone
        self.putts = putts
        self.penaltyStrokes = penaltyStrokes
        self.upAndDownAttempted = upAndDownAttempted
        self.upAndDownMade = upAndDownMade
        self.longPuttMade = longPuttMade
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.syncStatusRaw = syncStatusRaw
        self.round = round
    }

    /// Row C — total strokes = A + B. Derived, never stored. `nil` until both A and B entered.
    var total: Int? {
        guard let a = shotsToZone, let b = shotsInZone else { return nil }
        return a + b
    }

    /// Whether the golfer got "down in the scoring zone" — Row B within the target of 3.
    var isDownInThree: Bool? {
        guard let b = shotsInZone else { return nil }
        return b <= 3
    }

    /// A hole counts as "entered" the scoring zone if Row A was recorded.
    var hasEnteredZone: Bool { shotsToZone != nil }

    var isComplete: Bool { shotsToZone != nil && shotsInZone != nil }
}

@Model
final class ProfileModel: Syncable {
    @Attribute(.unique) var id: UUID    // == auth.users.id
    var fullName: String?
    var homeCourseId: UUID?
    var handicap: Double?
    var updatedAt: Date
    var deletedAt: Date?
    var syncStatusRaw: String

    init(
        id: UUID,
        fullName: String? = nil,
        homeCourseId: UUID? = nil,
        handicap: Double? = nil,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        syncStatusRaw: String = SyncStatus.pendingPush.rawValue
    ) {
        self.id = id
        self.fullName = fullName
        self.homeCourseId = homeCourseId
        self.handicap = handicap
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.syncStatusRaw = syncStatusRaw
    }
}
