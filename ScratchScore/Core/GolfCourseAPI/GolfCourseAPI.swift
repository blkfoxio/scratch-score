import Foundation

/// Client for golfcourseapi.com. The search endpoint returns full course objects
/// (including per-tee, per-hole par/yardage/handicap), so one call gives everything
/// we need to import — no separate detail request, which conserves the free quota.
///
/// Auth header format (per the provider): `Authorization: Key <API_KEY>`.
struct GolfCourseAPI {
    enum APIError: LocalizedError {
        case notConfigured
        case http(Int)
        case decoding(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Golf Course API key is not set."
            case let .http(code): return "Course search failed (HTTP \(code))."
            case let .decoding(msg): return "Couldn't read the course data. \(msg)"
            }
        }
    }

    private let base = URL(string: "https://api.golfcourseapi.com/v1")!
    private let session: URLSession = .shared

    var isConfigured: Bool { AppConfig.isCourseAPIConfigured }

    func search(_ query: String) async throws -> [APICourse] {
        guard isConfigured else { throw APIError.notConfigured }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(url: base.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "search_query", value: trimmed)]

        var request = URLRequest(url: components.url!)
        request.setValue("Key \(AppConfig.golfCourseAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw APIError.http(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(APISearchResponse.self, from: data).courses
        } catch {
            throw APIError.decoding(error.localizedDescription)
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
