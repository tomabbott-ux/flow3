import Foundation

struct SwedaviaLiveWaitTimeProvider: WaitTimeProviding {

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
        guard airport == .arn || airport == .got else { return [] }

        let code = airport.rawValue.uppercased()

        guard let url = URL(string: "https://www.swedavia.com/services/queuetimes/v2/airport/en/\(code)/true") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://www.swedavia.com/", forHTTPHeaderField: "Referer")
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

        let payload = try JSONDecoder().decode(SwedaviaQueueResponse.self, from: data)

        guard payload.queueTimesDisabled == false else {
            return []
        }

        let observedAt = Date()

        return payload.queueTimesList.map { item in
            let terminalNumber = item.terminalId.first.flatMap { Int($0) }

            let checkpointTitle = makeCheckpointTitle(for: airport, item: item)
            let subtitle = makeSubtitle(for: airport, item: item, terminalNumber: terminalNumber)
            let minutes = max(0, Int(ceil(Double(item.currentProjectedQueueTime) / 60.0)))

            return WaitTimeEstimate(
                airport: airport,
                terminal: terminalNumber,
                queueType: .general,
                minutes: minutes,
                observedAt: observedAt,
                checkpointName: checkpointTitle,
                areaName: subtitle,
                sourceType: .live,
                isClosed: item.isDisabled || item.isStationClosed
            )
        }
        .sorted { lhs, rhs in
            let leftTerminal = lhs.terminal ?? 0
            let rightTerminal = rhs.terminal ?? 0

            if leftTerminal == rightTerminal {
                return (lhs.checkpointName ?? "") < (rhs.checkpointName ?? "")
            }

            return leftTerminal < rightTerminal
        }
    }

    private func makeCheckpointTitle(for airport: FlowAirport, item: SwedaviaQueueItem) -> String {
        let displayEnglish = item.displayNameEnglish.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = item.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let short = item.shortName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = item.locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let terminal = item.terminalId.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if airport == .arn {
            if !displayEnglish.isEmpty {
                return "Terminal \(displayEnglish) Security"
            }

            if !display.isEmpty {
                return "Terminal \(display) Security"
            }

            if !short.isEmpty, !terminal.isEmpty {
                return "Terminal \(terminal)\(short) Security"
            }

            if !terminal.isEmpty {
                return "Terminal \(terminal) Security"
            }
        }

        if airport == .got {
            if !displayEnglish.isEmpty { return displayEnglish }
            if !display.isEmpty { return display }
            if !location.isEmpty, location.lowercased() != "security check" { return location }
            return name
        }

        if !displayEnglish.isEmpty { return displayEnglish }
        if !display.isEmpty { return display }
        if !short.isEmpty { return short }
        return name
    }

    private func makeSubtitle(for airport: FlowAirport, item: SwedaviaQueueItem, terminalNumber: Int?) -> String {
        let location = item.locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        if airport == .arn {
            return "Terminal"
        }

        if airport == .got {
            return "Terminal"
        }

        if !location.isEmpty {
            return location
        }

        if let terminalNumber {
            return "Terminal \(terminalNumber)"
        }

        return "Terminal"
    }
}

private struct SwedaviaQueueResponse: Decodable {
    let queueTimesDisabled: Bool
    let queueTimesReplacementMessage: String
    let queueTimesList: [SwedaviaQueueItem]
}

private struct SwedaviaQueueItem: Decodable {
    let id: Int
    let longId: String
    let terminalId: [String]
    let name: String
    let shortName: String
    let locationName: String
    let interval: String
    let currentProjectedQueueTime: Int
    let isFastTrack: Bool
    let isDisabled: Bool
    let hasTerminalMap: Bool
    let displayName: String
    let displayNameEnglish: String
    let overflow: Bool
    let isStationClosed: Bool
}
