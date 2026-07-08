import Foundation
import Supabase

/// Course search via golfcourseapi.com, proxied through the `course-search` Supabase
/// Edge Function so the provider API key stays server-side and is never shipped in the
/// app. The function requires an authenticated user and returns the provider's JSON
/// (full course objects incl. per-tee, per-hole par/yardage/handicap) verbatim.
struct GolfCourseAPI {
    enum APIError: LocalizedError {
        case notConfigured
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Course search isn't available right now."
            case let .failed(message): return message
            }
        }
    }

    private let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    /// Available whenever the backend is configured — the key lives in the Edge
    /// Function, so every signed-in user can search without supplying their own.
    var isConfigured: Bool { AppConfig.isBackendConfigured }

    func search(_ query: String) async throws -> [APICourse] {
        guard isConfigured else { throw APIError.notConfigured }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let response: APISearchResponse = try await supabase.functions.invoke(
                "course-search",
                options: FunctionInvokeOptions(body: ["q": trimmed]),
                decoder: decoder
            )
            return response.courses
        } catch {
            throw APIError.failed(error.localizedDescription)
        }
    }
}

// MARK: - Response DTOs (snake_case handled by .convertFromSnakeCase)

struct APISearchResponse: Decodable {
    let courses: [APICourse]
}

struct APICourse: Decodable, Identifiable {
    let id: Int
    let clubName: String?
    let courseName: String?
    let location: APILocation?
    let tees: APITees?

    /// All tees flattened, gendered so identical names don't collide.
    var allTees: [(name: String, tee: APITee)] {
        var result: [(String, APITee)] = []
        var used = Set<String>()
        func add(_ list: [APITee]?, _ gender: String) {
            for tee in list ?? [] {
                var name = tee.teeName ?? "Tee"
                if used.contains(name) { name = "\(name) (\(gender))" }
                used.insert(name)
                result.append((name, tee))
            }
        }
        add(tees?.male, "M")
        add(tees?.female, "W")
        return result
    }

    /// The tee with the most holes — used to define the course's par & stroke index.
    var referenceTee: APITee? {
        allTees.map(\.tee).max { $0.holes.count < $1.holes.count }
    }

    var displayName: String {
        let club = clubName?.trimmingCharacters(in: .whitespaces) ?? ""
        let course = courseName?.trimmingCharacters(in: .whitespaces) ?? ""
        if club.isEmpty { return course.isEmpty ? "Unknown course" : course }
        if course.isEmpty || course == club { return club }
        return "\(club) — \(course)"
    }
}

struct APILocation: Decodable {
    let address: String?
    let city: String?
    let state: String?
    let country: String?
}

struct APITees: Decodable {
    let male: [APITee]?
    let female: [APITee]?
}

struct APITee: Decodable {
    let teeName: String?
    let courseRating: Double?
    let slopeRating: Int?
    let totalYards: Int?
    let numberOfHoles: Int?
    let parTotal: Int?
    let holes: [APIHole]

    private enum CodingKeys: String, CodingKey {
        case teeName, courseRating, slopeRating, totalYards, numberOfHoles, parTotal, holes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        teeName = try c.decodeIfPresent(String.self, forKey: .teeName)
        courseRating = try c.decodeIfPresent(Double.self, forKey: .courseRating)
        slopeRating = try c.decodeIfPresent(Int.self, forKey: .slopeRating)
        totalYards = try c.decodeIfPresent(Int.self, forKey: .totalYards)
        numberOfHoles = try c.decodeIfPresent(Int.self, forKey: .numberOfHoles)
        parTotal = try c.decodeIfPresent(Int.self, forKey: .parTotal)
        holes = try c.decodeIfPresent([APIHole].self, forKey: .holes) ?? []
    }
}

struct APIHole: Decodable {
    let par: Int
    let yardage: Int?
    let handicap: Int?
}
