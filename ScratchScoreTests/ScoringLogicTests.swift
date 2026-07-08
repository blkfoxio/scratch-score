import XCTest
@testable import ScratchScore

final class ScoringLogicTests: XCTestCase {

    func testTotalIsAPlusB_puttsNotAdded() {
        let score = HoleScoreModel(holeNumber: 1, shotsToZone: 2, shotsInZone: 3, putts: 2)
        // Row C = A + B = 5. Putts (2) are part of B and must NOT be added again.
        XCTAssertEqual(score.total, 5)
    }

    func testTotalNilUntilBothEntered() {
        XCTAssertNil(HoleScoreModel(holeNumber: 1, shotsToZone: 2).total)
        XCTAssertNil(HoleScoreModel(holeNumber: 1, shotsInZone: 3).total)
    }

    func testDownInThreeThreshold() {
        XCTAssertEqual(HoleScoreModel(holeNumber: 1, shotsInZone: 3).isDownInThree, true)
        XCTAssertEqual(HoleScoreModel(holeNumber: 1, shotsInZone: 4).isDownInThree, false)
    }

    func testRoundFormatHoleRanges() {
        XCTAssertEqual(RoundFormat.frontNine.holeNumbers, Array(1...9))
        XCTAssertEqual(RoundFormat.backNine.holeNumbers, Array(10...18))
        XCTAssertEqual(RoundFormat.eighteen.holeNumbers.count, 18)
    }

    @MainActor
    func testRoundStatsAggregates() {
        let round = RoundModel(courseId: UUID(), courseName: "Test", format: .frontNine)
        round.holeScores = [
            HoleScoreModel(holeNumber: 1, shotsToZone: 2, shotsInZone: 2, putts: 1, round: round), // total 4, down in 3
            HoleScoreModel(holeNumber: 2, shotsToZone: 3, shotsInZone: 4, putts: 2, round: round)  // total 7, not down in 3
        ]
        let stats = RoundStats(round: round, parByHole: [1: 4, 2: 4])
        XCTAssertEqual(stats.holesPlayed, 2)
        XCTAssertEqual(stats.totalStrokes, 11)
        XCTAssertEqual(stats.totalPar, 8)
        XCTAssertEqual(stats.toPar, 3)
        XCTAssertEqual(stats.downInThreeCount, 1)
        XCTAssertEqual(stats.totalPutts, 3)
    }
}
