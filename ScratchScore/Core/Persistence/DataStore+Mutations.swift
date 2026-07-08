import Foundation
import SwiftData

/// UI-facing create/update/delete operations. Each mutation marks affected rows dirty
/// (`.pendingPush`) and saves; the caller then triggers a sync.
extension DataStore {
    // MARK: - Courses

    @discardableResult
    func createCourse(name: String, holeCount: Int, userId: UUID?) -> CourseModel {
        let course = CourseModel(userId: userId, name: name, holeCount: holeCount)
        context.insert(course)

        // Seed holes with sensible default par 4 and sequential stroke index.
        for number in 1...holeCount {
            let hole = HoleModel(userId: userId, holeNumber: number, par: 4,
                                 handicapIndex: number, course: course)
            context.insert(hole)
            course.holes.append(hole)
        }

        // Seed a default tee set.
        let tee = TeeSetModel(userId: userId, name: "White", course: course)
        context.insert(tee)
        course.teeSets.append(tee)

        save()
        return course
    }

    func touch(_ course: CourseModel) {
        course.markDirty()
        save()
    }

    func addTeeSet(to course: CourseModel, name: String, userId: UUID?) {
        let tee = TeeSetModel(userId: userId, name: name, course: course)
        context.insert(tee)
        course.teeSets.append(tee)
        course.markDirty()
        save()
    }

    func setYardage(_ value: Int?, hole: Int, teeSet: TeeSetModel, userId: UUID?) {
        if let existing = teeSet.yardages.first(where: { $0.holeNumber == hole && !$0.isTombstoned }) {
            existing.yardage = value
            existing.markDirty()
        } else {
            let y = TeeHoleYardageModel(userId: userId, holeNumber: hole, yardage: value, teeSet: teeSet)
            context.insert(y)
            teeSet.yardages.append(y)
        }
        recomputeTotalYardage(teeSet)
        teeSet.markDirty()
        save()
    }

    private func recomputeTotalYardage(_ teeSet: TeeSetModel) {
        let total = teeSet.yardages.filter { !$0.isTombstoned }.compactMap { $0.yardage }.reduce(0, +)
        teeSet.totalYardage = total > 0 ? total : nil
    }

    func softDeleteCourse(_ course: CourseModel) {
        course.softDelete()
        course.activeHoles.forEach { $0.softDelete() }
        course.activeTeeSets.forEach { tee in
            tee.softDelete()
            tee.yardages.filter { !$0.isTombstoned }.forEach { $0.softDelete() }
        }
        save()
    }

    // MARK: - Rounds

    @discardableResult
    func createRound(course: CourseModel, teeSet: TeeSetModel?, format: RoundFormat,
                     playedOn: Date, userId: UUID?) -> RoundModel {
        let round = RoundModel(userId: userId, courseId: course.id, teeSetId: teeSet?.id,
                               courseName: course.name, playedOn: playedOn, format: format)
        context.insert(round)
        for number in format.holeNumbers {
            let score = HoleScoreModel(userId: userId, holeNumber: number, round: round)
            context.insert(score)
            round.holeScores.append(score)
        }
        save()
        return round
    }

    func updateScore(_ score: HoleScoreModel, mutate: (HoleScoreModel) -> Void) {
        mutate(score)
        score.markDirty()
        score.round?.markDirty()
        save()
    }

    func finishRound(_ round: RoundModel) {
        round.status = .completed
        round.finishedAt = Date()
        round.markDirty()
        save()
    }

    func reopenRound(_ round: RoundModel) {
        round.status = .inProgress
        round.finishedAt = nil
        round.markDirty()
        save()
    }

    func softDeleteRound(_ round: RoundModel) {
        round.softDelete()
        round.activeScores.forEach { $0.softDelete() }
        save()
    }
}
