import Foundation
import SwiftData

/// Applies pulled DTOs into the local store using last-write-wins by `updated_at`.
/// Parents must be applied before children (the sync engine enforces table order).
extension DataStore {
    /// LWW guard: returns true if the remote row should overwrite the local one.
    private func remoteWins(localUpdatedAt: Date, remote: String?) -> Bool {
        guard let remoteDate = ISO8601.date(from: remote) else { return true }
        return remoteDate >= localUpdatedAt
    }

    private func uuid(_ s: String?) -> UUID? { s.flatMap(UUID.init(uuidString:)) }

    func applyProfile(_ dto: ProfileDTO) {
        guard let id = uuid(dto.id) else { return }
        let updatedAt = ISO8601.date(from: dto.updated_at) ?? Date()
        if let existing = profile(id: id) {
            guard remoteWins(localUpdatedAt: existing.updatedAt, remote: dto.updated_at) else { return }
            existing.fullName = dto.full_name
            existing.homeCourseId = uuid(dto.home_course_id)
            existing.handicap = dto.handicap
            existing.updatedAt = updatedAt
            existing.deletedAt = ISO8601.date(from: dto.deleted_at)
            existing.syncStatus = .synced
        } else if dto.deleted_at == nil {
            let p = ProfileModel(id: id, fullName: dto.full_name,
                                 homeCourseId: uuid(dto.home_course_id), handicap: dto.handicap,
                                 updatedAt: updatedAt, syncStatusRaw: SyncStatus.synced.rawValue)
            context.insert(p)
        }
    }

    func applyCourse(_ dto: CourseDTO) {
        guard let id = uuid(dto.id) else { return }
        let updatedAt = ISO8601.date(from: dto.updated_at) ?? Date()
        if let existing = course(id: id) {
            guard remoteWins(localUpdatedAt: existing.updatedAt, remote: dto.updated_at) else { return }
            if dto.deleted_at != nil { context.delete(existing); return }
            existing.name = dto.name
            existing.city = dto.city
            existing.region = dto.region
            existing.country = dto.country
            existing.externalRef = dto.external_ref
            existing.holeCount = dto.hole_count
            existing.userId = uuid(dto.user_id)
            existing.updatedAt = updatedAt
            existing.syncStatus = .synced
        } else if dto.deleted_at == nil {
            let c = CourseModel(id: id, userId: uuid(dto.user_id), name: dto.name,
                                city: dto.city, region: dto.region, country: dto.country,
                                externalRef: dto.external_ref, holeCount: dto.hole_count,
                                createdAt: ISO8601.date(from: dto.created_at) ?? Date(),
                                updatedAt: updatedAt, syncStatusRaw: SyncStatus.synced.rawValue)
            context.insert(c)
        }
    }

    func applyTeeSet(_ dto: TeeSetDTO) {
        guard let id = uuid(dto.id), let courseId = uuid(dto.course_id) else { return }
        let updatedAt = ISO8601.date(from: dto.updated_at) ?? Date()
        if let existing = teeSet(id: id) {
            guard remoteWins(localUpdatedAt: existing.updatedAt, remote: dto.updated_at) else { return }
            if dto.deleted_at != nil { context.delete(existing); return }
            existing.name = dto.name
            existing.color = dto.color
            existing.rating = dto.rating
            existing.slope = dto.slope
            existing.totalYardage = dto.total_yardage
            existing.userId = uuid(dto.user_id)
            existing.course = course(id: courseId)
            existing.updatedAt = updatedAt
            existing.syncStatus = .synced
        } else if dto.deleted_at == nil {
            let t = TeeSetModel(id: id, userId: uuid(dto.user_id), name: dto.name, color: dto.color,
                                rating: dto.rating, slope: dto.slope, totalYardage: dto.total_yardage,
                                updatedAt: updatedAt, syncStatusRaw: SyncStatus.synced.rawValue,
                                course: course(id: courseId))
            context.insert(t)
        }
    }

    func applyHole(_ dto: HoleDTO) {
        guard let id = uuid(dto.id), let courseId = uuid(dto.course_id) else { return }
        let updatedAt = ISO8601.date(from: dto.updated_at) ?? Date()
        if let existing = hole(id: id) {
            guard remoteWins(localUpdatedAt: existing.updatedAt, remote: dto.updated_at) else { return }
            if dto.deleted_at != nil { context.delete(existing); return }
            existing.holeNumber = dto.hole_number
            existing.par = dto.par
            existing.handicapIndex = dto.handicap_index
            existing.userId = uuid(dto.user_id)
            existing.course = course(id: courseId)
            existing.updatedAt = updatedAt
            existing.syncStatus = .synced
        } else if dto.deleted_at == nil {
            let h = HoleModel(id: id, userId: uuid(dto.user_id), holeNumber: dto.hole_number,
                              par: dto.par, handicapIndex: dto.handicap_index,
                              updatedAt: updatedAt, syncStatusRaw: SyncStatus.synced.rawValue,
                              course: course(id: courseId))
            context.insert(h)
        }
    }

    func applyYardage(_ dto: TeeHoleYardageDTO) {
        guard let id = uuid(dto.id), let teeSetId = uuid(dto.tee_set_id) else { return }
        let updatedAt = ISO8601.date(from: dto.updated_at) ?? Date()
        if let existing = yardage(id: id) {
            guard remoteWins(localUpdatedAt: existing.updatedAt, remote: dto.updated_at) else { return }
            if dto.deleted_at != nil { context.delete(existing); return }
            existing.holeNumber = dto.hole_number
            existing.yardage = dto.yardage
            existing.userId = uuid(dto.user_id)
            existing.teeSet = teeSet(id: teeSetId)
            existing.updatedAt = updatedAt
            existing.syncStatus = .synced
        } else if dto.deleted_at == nil {
            let y = TeeHoleYardageModel(id: id, userId: uuid(dto.user_id), holeNumber: dto.hole_number,
                                        yardage: dto.yardage, updatedAt: updatedAt,
                                        syncStatusRaw: SyncStatus.synced.rawValue,
                                        teeSet: teeSet(id: teeSetId))
            context.insert(y)
        }
    }

    func applyRound(_ dto: RoundDTO) {
        guard let id = uuid(dto.id), let courseId = uuid(dto.course_id) else { return }
        let updatedAt = ISO8601.date(from: dto.updated_at) ?? Date()
        if let existing = round(id: id) {
            guard remoteWins(localUpdatedAt: existing.updatedAt, remote: dto.updated_at) else { return }
            if dto.deleted_at != nil { context.delete(existing); return }
            existing.courseId = courseId
            existing.teeSetId = uuid(dto.tee_set_id)
            existing.courseName = dto.course_name ?? existing.courseName
            existing.playedOn = ISO8601.day(from: dto.played_on) ?? existing.playedOn
            existing.startedAt = ISO8601.date(from: dto.started_at) ?? existing.startedAt
            existing.finishedAt = ISO8601.date(from: dto.finished_at)
            existing.statusRaw = dto.status
            existing.formatRaw = dto.format
            existing.notes = dto.notes
            existing.userId = uuid(dto.user_id)
            existing.updatedAt = updatedAt
            existing.syncStatus = .synced
        } else if dto.deleted_at == nil {
            let r = RoundModel(id: id, userId: uuid(dto.user_id), courseId: courseId,
                               teeSetId: uuid(dto.tee_set_id), courseName: dto.course_name ?? "Course",
                               playedOn: ISO8601.day(from: dto.played_on) ?? Date(),
                               startedAt: ISO8601.date(from: dto.started_at) ?? Date(),
                               finishedAt: ISO8601.date(from: dto.finished_at),
                               status: RoundStatus(rawValue: dto.status) ?? .inProgress,
                               format: RoundFormat(rawValue: dto.format) ?? .eighteen,
                               notes: dto.notes, updatedAt: updatedAt,
                               syncStatusRaw: SyncStatus.synced.rawValue)
            context.insert(r)
        }
    }

    func applyHoleScore(_ dto: HoleScoreDTO) {
        guard let id = uuid(dto.id), let roundId = uuid(dto.round_id) else { return }
        let updatedAt = ISO8601.date(from: dto.updated_at) ?? Date()
        if let existing = holeScore(id: id) {
            guard remoteWins(localUpdatedAt: existing.updatedAt, remote: dto.updated_at) else { return }
            if dto.deleted_at != nil { context.delete(existing); return }
            apply(dto, to: existing, updatedAt: updatedAt, roundId: roundId)
        } else if dto.deleted_at == nil {
            let s = HoleScoreModel(id: id, holeNumber: dto.hole_number)
            apply(dto, to: s, updatedAt: updatedAt, roundId: roundId)
            context.insert(s)
        }
    }

    private func apply(_ dto: HoleScoreDTO, to model: HoleScoreModel, updatedAt: Date, roundId: UUID) {
        model.holeNumber = dto.hole_number
        model.shotsToZone = dto.shots_to_zone
        model.shotsInZone = dto.shots_in_zone
        model.putts = dto.putts
        model.penaltyStrokes = dto.penalty_strokes
        model.upAndDownAttempted = dto.up_and_down_attempted
        model.upAndDownMade = dto.up_and_down_made
        model.longPuttMade = dto.long_putt_made
        model.userId = uuid(dto.user_id)
        model.round = round(id: roundId)
        model.updatedAt = updatedAt
        model.syncStatus = .synced
    }
}
