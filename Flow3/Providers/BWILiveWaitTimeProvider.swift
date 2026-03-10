import Foundation

final class BWILiveWaitTimeProvider: WaitTimeProviding {

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

        guard airport == .bwi else { return [] }

        guard let url = URL(string: "https://bwiairport.com/wp-content/themes/bwitheme/ajaxcall.php?action=get_waitTimes_data") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("https://bwiairport.com", forHTTPHeaderField: "Origin")
        request.setValue("https://bwiairport.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        request.httpBody = "themeRootDir=https%3A%2F%2Fbwiairport.com%2Fwp-content%2Fthemes%2Fbwitheme%2F".data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        let payload = try JSONDecoder().decode(BWIResponse.self, from: data)
        let now = Date()

        return payload.waitTimes.waittimes.compactMap { item in
            let queueName = item.queueName.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = queueName.uppercased()

            guard upper.contains("GENERAL") || upper.contains("PRECHECK") else {
                return nil
            }

            let queueType: QueueType = upper.contains("PRECHECK") ? .precheck : .general
            let checkpointTitle = checkpointTitle(from: queueName)
            let observedAt = parseDate(item.updatedTime) ?? now
            let minutes = Int(item.projectedWaitTime) ?? Int(item.projectedMinWaitMinutes) ?? 0
            let isClosed = normalizedState(item.queueState).contains("CLOS")

            return WaitTimeEstimate(
                airport: .bwi,
                terminal: nil,
                queueType: queueType,
                minutes: max(0, minutes),
                observedAt: observedAt,
                checkpointName: checkpointTitle,
                areaName: "BWI",
                sourceType: .live,
                isClosed: isClosed
            )
        }
    }

    private func checkpointTitle(from queueName: String) -> String {
        queueName
            .replacingOccurrences(of: " General", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: " PreCheck", with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedState(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func parseDate(_ value: String) -> Date? {
        if let date = isoFormatterWithFractional.date(from: value) {
            return date
        }

        if let date = isoFormatter.date(from: value) {
            return date
        }

        return nil
    }

    private let isoFormatterWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

private struct BWIResponse: Decodable {
    let waitTimes: BWIWaitTimesContainer

    enum CodingKeys: String, CodingKey {
        case waitTimes
    }
}

private struct BWIWaitTimesContainer: Decodable {
    let updated: String
    let waittimes: [BWIQueue]
}

private struct BWIQueue: Decodable {
    let queueID: String
    let queueName: String
    let projectedWaitTime: String
    let projectedMinWaitMinutes: String
    let projectedMaxWaitMinutes: String
    let queueState: String
    let updatedTime: String

    enum CodingKeys: String, CodingKey {
        case queueID = "Queue_ID"
        case queueName = "Queue_Name"
        case projectedWaitTime = "Projected_Wait_Time"
        case projectedMinWaitMinutes = "Projected_Min_Wait_Minutes"
        case projectedMaxWaitMinutes = "Projected_Max_Wait_Minutes"
        case queueState = "Queue_State"
        case updatedTime = "Updated_Time"
    }
}
