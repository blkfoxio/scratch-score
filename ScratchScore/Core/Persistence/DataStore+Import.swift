import Foundation
import SwiftData

extension DataStore {
    private func externalRef(_ id: Int) -> String { "golfcourseapi:\(id)" }

    /// Returns an already-imported (active) course for this external id, if any.
    func importedCourse(externalId: Int) -> CourseModel? {
        let ref = externalRef(externalId)
        return allCourses().first { $0.externalRef == ref }
    }

    /// Maps a Golf Course API result into our local model graph (course + holes +
    /// tee sets + per-tee yardages). Idempotent: re-importing the same course returns
    /// the existing one rather than duplicating.
    @discardableResult
    func importCourse(_ api: APICourse, userId: UUID?) -> CourseModel {
        if let existing = importedCourse(externalId: api.id) { return existing }

        // Par & stroke index come from the tee with the most holes (they're course-level).
        let reference = api.referenceTee
        let sourceHoles = Array((reference?.holes ?? []).prefix(18))
        let holeCount = sourceHoles.count == 9 ? 9 : 18

        let course = CourseModel(
            userId: userId,
            name: api.displayName,
            city: api.location?.city,
            region: api.location?.state,
            country: api.location?.country,
            externalRef: externalRef(api.id),
            holeCount: holeCount
        )
        context.insert(course)

        for (index, hole) in sourceHoles.enumerated() {
            let model = HoleModel(
                userId: userId,
                holeNumber: index + 1,
                par: hole.par,
                handicapIndex: hole.handicap,
                course: course
            )
            context.insert(model)
            course.holes.append(model)
        }

        for (name, tee) in api.allTees {
            let teeSet = TeeSetModel(
                userId: userId,
                name: name,
                rating: tee.courseRating,
                slope: tee.slopeRating,
                totalYardage: tee.totalYards,
                course: course
            )
            context.insert(teeSet)
            course.teeSets.append(teeSet)

            for (index, hole) in tee.holes.prefix(18).enumerated() {
                guard let yards = hole.yardage else { continue }
                let yardage = TeeHoleYardageModel(
                    userId: userId,
                    holeNumber: index + 1,
                    yardage: yards,
                    teeSet: teeSet
                )
                context.insert(yardage)
                teeSet.yardages.append(yardage)
            }
        }

        save()
        return course
    }
}
