import Foundation
import SwiftData

@Model
final class CourseModel: Syncable {
    @Attribute(.unique) var id: UUID
    var userId: UUID?
    var name: String
    var city: String?
    var region: String?
    var country: String?
    /// Provider id for a future course-import API. Nil for manually-entered courses.
    var externalRef: String?
    var holeCount: Int
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var syncStatusRaw: String

    @Relationship(deleteRule: .cascade, inverse: \HoleModel.course)
    var holes: [HoleModel] = []

    @Relationship(deleteRule: .cascade, inverse: \TeeSetModel.course)
    var teeSets: [TeeSetModel] = []

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        name: String,
        city: String? = nil,
        region: String? = nil,
        country: String? = nil,
        externalRef: String? = nil,
        holeCount: Int = 18,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        syncStatusRaw: String = SyncStatus.pendingPush.rawValue
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.city = city
        self.region = region
        self.country = country
        self.externalRef = externalRef
        self.holeCount = holeCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.syncStatusRaw = syncStatusRaw
    }

    var activeHoles: [HoleModel] {
        holes.filter { !$0.isTombstoned }.sorted { $0.holeNumber < $1.holeNumber }
    }

    var activeTeeSets: [TeeSetModel] {
        teeSets.filter { !$0.isTombstoned }.sorted { $0.name < $1.name }
    }

    var totalPar: Int { activeHoles.reduce(0) { $0 + $1.par } }

    var locationLine: String {
        [city, region].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

@Model
final class TeeSetModel: Syncable {
    @Attribute(.unique) var id: UUID
    var userId: UUID?
    var name: String
    var color: String?
    var rating: Double?
    var slope: Int?
    var totalYardage: Int?
    var updatedAt: Date
    var deletedAt: Date?
    var syncStatusRaw: String

    var course: CourseModel?

    @Relationship(deleteRule: .cascade, inverse: \TeeHoleYardageModel.teeSet)
    var yardages: [TeeHoleYardageModel] = []

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        name: String,
        color: String? = nil,
        rating: Double? = nil,
        slope: Int? = nil,
        totalYardage: Int? = nil,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        syncStatusRaw: String = SyncStatus.pendingPush.rawValue,
        course: CourseModel? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.color = color
        self.rating = rating
        self.slope = slope
        self.totalYardage = totalYardage
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.syncStatusRaw = syncStatusRaw
        self.course = course
    }

    func yardage(forHole holeNumber: Int) -> Int? {
        yardages.first { $0.holeNumber == holeNumber && !$0.isTombstoned }?.yardage
    }
}

@Model
final class HoleModel: Syncable {
    @Attribute(.unique) var id: UUID
    var userId: UUID?
    var holeNumber: Int
    var par: Int
    /// Stroke index / handicap ranking (1 = hardest).
    var handicapIndex: Int?
    var updatedAt: Date
    var deletedAt: Date?
    var syncStatusRaw: String

    var course: CourseModel?

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        holeNumber: Int,
        par: Int,
        handicapIndex: Int? = nil,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        syncStatusRaw: String = SyncStatus.pendingPush.rawValue,
        course: CourseModel? = nil
    ) {
        self.id = id
        self.userId = userId
        self.holeNumber = holeNumber
        self.par = par
        self.handicapIndex = handicapIndex
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.syncStatusRaw = syncStatusRaw
        self.course = course
    }
}

@Model
final class TeeHoleYardageModel: Syncable {
    @Attribute(.unique) var id: UUID
    var userId: UUID?
    var holeNumber: Int
    var yardage: Int?
    var updatedAt: Date
    var deletedAt: Date?
    var syncStatusRaw: String

    var teeSet: TeeSetModel?

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        holeNumber: Int,
        yardage: Int? = nil,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        syncStatusRaw: String = SyncStatus.pendingPush.rawValue,
        teeSet: TeeSetModel? = nil
    ) {
        self.id = id
        self.userId = userId
        self.holeNumber = holeNumber
        self.yardage = yardage
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.syncStatusRaw = syncStatusRaw
        self.teeSet = teeSet
    }
}
