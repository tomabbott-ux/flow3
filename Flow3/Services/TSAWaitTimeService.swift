import Foundation

struct TSAWaitTimeService {

    // Replace with your real TSAWaitTimes key
    private let apiKey = "VrEVxLfcl7O1TTWYgzU8sxpvW6ZmNbvr"

    func fetchWaitTimes(for airportCode: String) async throws -> TSAAirportWaitResponse {
        guard !apiKey.isEmpty, apiKey != "PASTE_YOUR_REAL_TSA_KEY_HERE" else {
            throw URLError(.userAuthenticationRequired)
        }

        let code = airportCode.uppercased()

        guard let url = URL(string: "https://www.tsawaittimes.com/api/airport/\(apiKey)/\(code)/JSON") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20

        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse {
            print("TSA status:", http.statusCode)
        }
        print("TSA raw:", String(data: data, encoding: .utf8) ?? "<non-utf8>")

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8>"
            print("TSA API failed:", http.statusCode, body)
            throw URLError(.badServerResponse)
        }

        do {
            return try JSONDecoder().decode(TSAAirportWaitResponse.self, from: data)
        } catch {
            print("TSA decode failed:", error.localizedDescription)
            throw error
        }
    }
}

struct TSAAirportWaitResponse: Decodable {
    let code: String?
    let name: String?
    let city: String?
    let state: String?
    let latitude: String?
    let longitude: String?
    let utc: Int?
    let rightnow: Int?
    let rightnowDescription: String?
    let userReported: Int?
    let precheck: Int?
    let faaAlerts: TSAFAAAlerts?
    let estimatedHourlyTimes: [TSAHourlyEstimate]?
    let precheckCheckpoints: [String: [String: String]]?

    enum CodingKeys: String, CodingKey {
        case code
        case name
        case city
        case state
        case latitude
        case longitude
        case utc
        case rightnow
        case rightnowDescription = "rightnow_description"
        case userReported = "user_reported"
        case precheck
        case faaAlerts = "faa_alerts"
        case estimatedHourlyTimes = "estimated_hourly_times"
        case precheckCheckpoints = "precheck_checkpoints"
    }

    var resolvedGeneralMinutes: Int? {
        if let rightnow {
            return rightnow
        }

        if let currentHour = Calendar.current.dateComponents([.hour], from: Date()).hour,
           let hourly = estimatedHourlyTimes?.first(where: { $0.hour == currentHour })?.waittime {
            return Int(hourly.rounded())
        }

        if let fallbackHourly = estimatedHourlyTimes?.first?.waittime {
            return Int(fallbackHourly.rounded())
        }

        return nil
    }

    var resolvedPrecheckMinutes: Int? {
        guard precheck == 1 else { return nil }

        let allStatuses = precheckCheckpoints?
            .flatMap { $0.value.values }
            .map { $0.lowercased() } ?? []

        let hasOpenPrecheck = allStatuses.contains("open")

        guard hasOpenPrecheck else { return nil }

        if let general = resolvedGeneralMinutes {
            return max(1, general - 3)
        }

        return 5
    }
}

struct TSAFAAAlerts: Decodable {
    let groundStops: TSAAlertDetail?
    let groundDelays: TSAAlertDetail?
    let generalDelays: TSAAlertDetail?

    enum CodingKeys: String, CodingKey {
        case groundStops = "ground_stops"
        case groundDelays = "ground_delays"
        case generalDelays = "general_delays"
    }
}

struct TSAAlertDetail: Decodable {
    let reason: String?
    let endTime: String?
    let average: String?
    let trend: String?

    enum CodingKeys: String, CodingKey {
        case reason
        case endTime = "end_time"
        case average
        case trend
    }
}

struct TSAHourlyEstimate: Decodable {
    let timeslot: String?
    let waittime: Double?
    let hour: Int?

    enum CodingKeys: String, CodingKey {
        case timeslot
        case waittime
        case hour
    }
}
