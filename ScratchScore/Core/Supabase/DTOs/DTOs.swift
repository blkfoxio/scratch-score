import Foundation

/// Wire-format structs that exactly match Postgres columns (snake_case). Kept separate
/// from the SwiftData `@Model` classes so the storage layer and the sync layer stay
/// decoupled. Timestamps are transported as ISO8601 strings (see `ISO8601`).
///
/// Every DTO carries `updated_at` and `deleted_at` to drive delta-pull + tombstones.

struct ProfileDTO: Codable, Identifiable {
    var id: String
    var full_name: String?
    var home_course_id: String?
    var handicap: Double?
    var updated_at: String?
    var deleted_at: String?
}

struct CourseDTO: Codable, Identifiable {
    var id: String
    var user_id: String?
    var name: String
    var city: String?
    var region: String?
    var country: String?
    var external_ref: String?
    var hole_count: Int
    var created_at: String?
    var updated_at: String?
    var deleted_at: String?
}

struct TeeSetDTO: Codable, Identifiable {
    var id: String
    var user_id: String?
    var course_id: String
    var name: String
    var color: String?
    var rating: Double?
    var slope: Int?
    var total_yardage: Int?
    var updated_at: String?
    var deleted_at: String?
}

struct HoleDTO: Codable, Identifiable {
    var id: String
    var user_id: String?
    var course_id: String
    var hole_number: Int
    var par: Int
    var handicap_index: Int?
    var updated_at: String?
    var deleted_at: String?
}

struct TeeHoleYardageDTO: Codable, Identifiable {
    var id: String
    var user_id: String?
    var tee_set_id: String
    var hole_number: Int
    var yardage: Int?
    var updated_at: String?
    var deleted_at: String?
}

struct RoundDTO: Codable, Identifiable {
    var id: String
    var user_id: String?
    var course_id: String
    var tee_set_id: String?
    var course_name: String?
    var played_on: String?
    var started_at: String?
    var finished_at: String?
    var status: String
    var format: String
    var notes: String?
    var updated_at: String?
    var deleted_at: String?
}

struct HoleScoreDTO: Codable, Identifiable {
    var id: String
    var user_id: String?
    var round_id: String
    var hole_number: Int
    var shots_to_zone: Int?
    var shots_in_zone: Int?
    var putts: Int?
    var penalty_strokes: Int
    var up_and_down_attempted: Bool
    var up_and_down_made: Bool
    var long_putt_made: Bool
    var updated_at: String?
    var deleted_at: String?
}
