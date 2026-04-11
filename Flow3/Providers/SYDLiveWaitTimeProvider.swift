import Foundation

final class SYDLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case unsupportedAirport
        case invalidURL
        case invalidResponse
        case badHTTPStatus(Int)
        case emptyData
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .syd else {
            throw ProviderError.unsupportedAirport
        }

        guard let url = URL(string: "https://www.sydneyairport.com.au/_a/security-wait-times") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 6
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("https://www.sydneyairport.com.au/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.2 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        let rows = try JSONDecoder().decode([SYDTerminalPayload].self, from: data)

        guard !rows.isEmpty else {
            throw ProviderError.emptyData
        }

        let now = Date()

        let results = rows.compactMap { row -> WaitTimeEstimate? in
            let terminalName = row.terminal.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !terminalName.isEmpty else { return nil }

            let terminalNumber = inferredTerminal(from: terminalName)
            let observedAt = parsedObservedAt(from: row.data) ?? now

            return WaitTimeEstimate(
                airport: .syd,
                terminal: terminalNumber,
                queueType: .general,
                minutes: max(0, row.data.value),
                observedAt: observedAt,
                checkpointName: terminalName,
                areaName: terminalAreaName(for: terminalName),
                sourceType: .live,
                isClosed: false
            )
        }

        guard !results.isEmpty else {
            throw ProviderError.emptyData
        }

        return results.sorted {
            terminalSortOrder(for: $0.checkpointName ?? "") < terminalSortOrder(for: $1.checkpointName ?? "")
        }
    }

    private func inferredTerminal(from name: String) -> Int? {
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "terminal 1":
            return 1
        case "terminal 2":
            return 2
        case "terminal 3":
            return 3
        default:
            return nil
        }
    }

    private func terminalAreaName(for terminalName: String) -> String {
        switch terminalName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "terminal 1":
            return "International"
        case "terminal 2":
            return "Domestic"
        case "terminal 3":
            return "Domestic"
        default:
            return "Sydney"
        }
    }

    private func terminalSortOrder(for checkpointName: String) -> Int {
        switch checkpointName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "terminal 1":
            return 1
        case "terminal 2":
            return 2
        case "terminal 3":
            return 3
        default:
            return 999
        }
    }

    private func parsedObservedAt(from data: SYDTerminalPayload.TerminalData) -> Date? {
        let dateText = data.date.trimmingCharacters(in: .whitespacesAndNewlines)
        let refreshText = data.refreshtime.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !dateText.isEmpty, !refreshText.isEmpty else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.timeZone = FlowAirport.syd.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return formatter.date(from: "\(dateText) \(refreshText)")
    }
}

private struct SYDTerminalPayload: Decodable {
    let terminal: String
    let data: TerminalData

    struct TerminalData: Decodable {
        let date: String
        let attribute: String
        let refreshtime: String
        let value: Int
    }
}
