import Foundation

struct LHRLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case invalidURL
        case invalidResponse
        case badHTTPStatus(Int)
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .lhr else { return [] }

        guard let url = URL(
            string: "https://api-dp-prod.dp.heathrow.com/pihub/securitywaittime?checkpointFacilityType=securityStandard"
        ) else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://www.heathrow.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://www.heathrow.com", forHTTPHeaderField: "Origin")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.3 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Self.dateFormatter)

        let payload = try decoder.decode([LHRSecurityItem].self, from: data)

        let rows: [WaitTimeEstimate] = payload.compactMap { item in
            guard item.queueType.code == "security" else { return nil }
            guard item.checkpointFacility.checkpointFacilityType.code == "securityStandard" else { return nil }

            let terminalCode = item.checkpointFacility.terminalFacility.code
            guard let terminal = Int(terminalCode) else { return nil }

            let maxWait = item.queueMeasurements.first(where: { $0.name == "maximumWaitTime" })?.value
            let minWait = item.queueMeasurements.first(where: { $0.name == "minimumWaitTime" })?.value

            let minutes: Int
            if let maxWait, maxWait >= 0 {
                minutes = maxWait
            } else if let minWait, minWait >= 0 {
                minutes = minWait
            } else {
                minutes = 0
            }

            let checkpointName: String
            if terminal == 5 {
                switch item.checkpointFacility.area?.uppercased() {
                case "N":
                    checkpointName = "North"
                case "S":
                    checkpointName = "South"
                default:
                    checkpointName = "Security"
                }
            } else {
                checkpointName = "Security"
            }

            return WaitTimeEstimate(
                airport: .lhr,
                terminal: terminal,
                queueType: .general,
                minutes: minutes,
                observedAt: item.lastUpdated,
                checkpointName: checkpointName,
                areaName: nil,
                sourceType: .live,
                isClosed: item.isDataStale
            )
        }

        return rows.sorted {
            let leftTerminal = $0.terminal ?? 0
            let rightTerminal = $1.terminal ?? 0

            if leftTerminal == rightTerminal {
                return ($0.checkpointName ?? "") < ($1.checkpointName ?? "")
            }

            return leftTerminal < rightTerminal
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}

private struct LHRSecurityItem: Decodable {
    let lastUpdated: Date
    let isDataStale: Bool
    let queueType: LHRQueueType
    let checkpointFacility: LHRCheckpointFacility
    let queueMeasurements: [LHRQueueMeasurement]
    let waitTimeRangeMinutes: String
    let waitTimeMessage: String
    let additionalMessages: [String]
}

private struct LHRQueueType: Decodable {
    let code: String
}

private struct LHRCheckpointFacility: Decodable {
    let checkpointFacilityType: LHRCheckpointFacilityType
    let terminalFacility: LHRTerminalFacility
    let area: String?
}

private struct LHRCheckpointFacilityType: Decodable {
    let code: String
}

private struct LHRTerminalFacility: Decodable {
    let code: String
}

private struct LHRQueueMeasurement: Decodable {
    let name: String
    let value: Int
    let unitOfMeasurement: LHRUnitOfMeasurement
}

private struct LHRUnitOfMeasurement: Decodable {
    let name: String
}
