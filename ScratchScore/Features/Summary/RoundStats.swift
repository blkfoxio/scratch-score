import Foundation

/// Derived scoring statistics for a single round, computed locally from hole scores.
/// `parByHole` maps hole number → par (from the round's course); pass an empty map if
/// the course is unavailable and par-relative figures will be omitted.
struct RoundStats {
    let holesPlayed: Int
    let holesInFormat: Int
    let totalStrokes: Int
    let totalPar: Int
    let hasPar: Bool

    let frontStrokes: Int
    let backStrokes: Int

    /// Holes where the golfer got "down in the scoring zone" (Row B ≤ 3).
    let downInThreeCount: Int
    let zoneEfficiency: Double?          // downInThree / holesPlayed
    let avgShotsToZone: Double?          // Row A average

    let totalPutts: Int
    let penalties: Int
    let upDownAttempts: Int
    let upDownMade: Int
    let upDownRate: Double?

    var toPar: Int { totalStrokes - totalPar }

    init(round: RoundModel, parByHole: [Int: Int]) {
        let scores = round.activeScores.filter { $0.isComplete }
        holesInFormat = round.format.holeNumbers.count
        holesPlayed = scores.count
        hasPar = !parByHole.isEmpty

        totalStrokes = scores.compactMap { $0.total }.reduce(0, +)
        totalPar = scores.reduce(0) { $0 + (parByHole[$1.holeNumber] ?? 0) }

        frontStrokes = scores.filter { $0.holeNumber <= 9 }.compactMap { $0.total }.reduce(0, +)
        backStrokes = scores.filter { $0.holeNumber >= 10 }.compactMap { $0.total }.reduce(0, +)

        let downInThree = scores.filter { ($0.isDownInThree ?? false) }.count
        downInThreeCount = downInThree
        zoneEfficiency = holesPlayed > 0 ? Double(downInThree) / Double(holesPlayed) : nil

        let aValues = scores.compactMap { $0.shotsToZone }
        avgShotsToZone = aValues.isEmpty ? nil : Double(aValues.reduce(0, +)) / Double(aValues.count)

        totalPutts = scores.compactMap { $0.putts }.reduce(0, +)
        penalties = round.activeScores.reduce(0) { $0 + $1.penaltyStrokes }

        let attempts = round.activeScores.filter { $0.upAndDownAttempted }
        upDownAttempts = attempts.count
        upDownMade = attempts.filter { $0.upAndDownMade }.count
        upDownRate = upDownAttempts > 0 ? Double(upDownMade) / Double(upDownAttempts) : nil
    }

    var toParString: String {
        guard hasPar else { return "—" }
        if toPar == 0 { return "E" }
        return toPar > 0 ? "+\(toPar)" : "\(toPar)"
    }

    static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }
}
