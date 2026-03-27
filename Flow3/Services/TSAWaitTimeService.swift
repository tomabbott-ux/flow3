import Foundation

struct TSAWaitTimeService {
    func fetchWaitTimes(for airportCode: String) async throws -> TSAAirportWaitResponse {
        throw URLError(.unsupportedURL)
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

    var resolvedGeneralMinutes: Int? { nil }
    var resolvedPrecheckMinutes: Int? { nil }
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
