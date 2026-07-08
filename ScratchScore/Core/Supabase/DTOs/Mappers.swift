import Foundation

/// Local `@Model` → wire DTO. The reverse direction (apply DTO to local store) lives in
/// `DataStore.applyRemote(...)` because it needs to fetch-or-create by UUID.

extension ProfileModel {
    func toDTO() -> ProfileDTO {
        ProfileDTO(
            id: id.uuidString,
            full_name: fullName,
            home_course_id: homeCourseId?.uuidString,
            handicap: handicap,
            updated_at: ISO8601.string(from: updatedAt),
            deleted_at: ISO8601.string(from: deletedAt)
        )
    }
}

extension CourseModel {
    func toDTO(userId: UUID) -> CourseDTO {
        CourseDTO(
            id: id.uuidString,
            user_id: userId.uuidString,
            name: name,
            city: city,
            region: region,
            country: country,
            external_ref: externalRef,
            hole_count: holeCount,
            created_at: ISO8601.string(from: createdAt),
            updated_at: ISO8601.string(from: updatedAt),
            deleted_at: ISO8601.string(from: deletedAt)
        )
    }
}

extension TeeSetModel {
    func toDTO(userId: UUID, courseId: UUID) -> TeeSetDTO {
        TeeSetDTO(
            id: id.uuidString,
            user_id: userId.uuidString,
            course_id: courseId.uuidString,
            name: name,
            color: color,
            rating: rating,
            slope: slope,
            total_yardage: totalYardage,
            updated_at: ISO8601.string(from: updatedAt),
            deleted_at: ISO8601.string(from: deletedAt)
        )
    }
}

extension HoleModel {
    func toDTO(userId: UUID, courseId: UUID) -> HoleDTO {
        HoleDTO(
            id: id.uuidString,
            user_id: userId.uuidString,
            course_id: courseId.uuidString,
            hole_number: holeNumber,
            par: par,
            handicap_index: handicapIndex,
            updated_at: ISO8601.string(from: updatedAt),
            deleted_at: ISO8601.string(from: deletedAt)
        )
    }
}

extension TeeHoleYardageModel {
    func toDTO(userId: UUID, teeSetId: UUID) -> TeeHoleYardageDTO {
        TeeHoleYardageDTO(
            id: id.uuidString,
            user_id: userId.uuidString,
            tee_set_id: teeSetId.uuidString,
            hole_number: holeNumber,
            yardage: yardage,
            updated_at: ISO8601.string(from: updatedAt),
            deleted_at: ISO8601.string(from: deletedAt)
        )
    }
}

extension RoundModel {
    func toDTO(userId: UUID) -> RoundDTO {
        RoundDTO(
            id: id.uuidString,
            user_id: userId.uuidString,
            course_id: courseId.uuidString,
            tee_set_id: teeSetId?.uuidString,
            course_name: courseName,
            played_on: ISO8601.dayString(from: playedOn),
            started_at: ISO8601.string(from: startedAt),
            finished_at: ISO8601.string(from: finishedAt),
            status: statusRaw,
            format: formatRaw,
            notes: notes,
            updated_at: ISO8601.string(from: updatedAt),
            deleted_at: ISO8601.string(from: deletedAt)
        )
    }
}

extension HoleScoreModel {
    func toDTO(userId: UUID, roundId: UUID) -> HoleScoreDTO {
        HoleScoreDTO(
            id: id.uuidString,
            user_id: userId.uuidString,
            round_id: roundId.uuidString,
            hole_number: holeNumber,
            shots_to_zone: shotsToZone,
            shots_in_zone: shotsInZone,
            putts: putts,
            penalty_strokes: penaltyStrokes,
            up_and_down_attempted: upAndDownAttempted,
            up_and_down_made: upAndDownMade,
            long_putt_made: longPuttMade,
            updated_at: ISO8601.string(from: updatedAt),
            deleted_at: ISO8601.string(from: deletedAt)
        )
    }
}
