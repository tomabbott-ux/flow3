import Foundation

final class DCALiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case invalidURL
        case badHTTPStatus(Int)
        case invalidResponse
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard airport == .dca else { return [] }

        guard let url = URL(string: "https://www.flyreagan.com/security-wait-times") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("https://www.flyreagan.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.flyreagan.com/", forHTTPHeaderField: "Referer")
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

        let payload = try JSONDecoder().decode(DCAResponse.self, from: data)
        let now = Date()

        return payload.response.res.flatMap { key, item -> [WaitTimeEstimate] in
            var rows: [WaitTimeEstimate] = []

            let title = item.location.trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = cleanedGates(item.gates)

            if item.isDisabled == 0, let generalMinutes = parseMinutes(item.waittime) {
                rows.append(
                    WaitTimeEstimate(
                        airport: .dca,
                        terminal: nil,
                        queueType: .general,
                        minutes: generalMinutes,
                        observedAt: now,
                        checkpointName: title,
                        areaName: subtitle,
                        sourceType: .live,
                        isClosed: false
                    )
                )
            }

            if item.preDisabled == 0, let preMinutes = parseMinutes(item.pre) {
                rows.append(
                    WaitTimeEstimate(
                        airport: .dca,
                        terminal: nil,
                        queueType: .precheck,
                        minutes: preMinutes,
                        observedAt: now,
                        checkpointName: title,
                        areaName: subtitle,
                        sourceType: .live,
                        isClosed: false
                    )
                )
            }

            return rows
        }
        .sorted { lhs, rhs in
            if lhs.checkpointName == rhs.checkpointName {
                return lhs.queueType.rawValue < rhs.queueType.rawValue
            }
            return (lhs.checkpointName ?? "") < (rhs.checkpointName ?? "")
        }
    }

    private func parseMinutes(_ value: String?) -> Int? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return nil
        }

        if trimmed.contains("<") {
            let digits = trimmed.filter(\.isNumber)
            return Int(digits)
        }

        let digits = trimmed.filter(\.isNumber)
        return Int(digits)
    }

    private func cleanedGates(_ value: String?) -> String {
        guard let value else { return "DCA" }

        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: " ()"))
        return trimmed.isEmpty ? "DCA" : trimmed
    }
}

private struct DCAResponse: Decodable {
    let response: DCAResponseContainer
}

private struct DCAResponseContainer: Decodable {
    let isMulti: Bool
    let res: [String: DCACheckpoint]
}

private struct DCACheckpoint: Decodable {
    let pre: String?
    let location: String
    let waittime: String
    let gates: String?
    let isDisabled: Int
    let preDisabled: Int

    enum CodingKeys: String, CodingKey {
        case pre
        case location
        case waittime
        case gates
        case isDisabled = "isDisabled"
        case preDisabled = "pre_disabled"
    }
}
