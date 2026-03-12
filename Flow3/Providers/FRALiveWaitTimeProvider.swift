import Foundation

struct FRALiveWaitTimeProvider: WaitTimeProviding {

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
        guard airport == .fra else { return [] }

        guard let url = URL(string: "https://www.frankfurt-airport.com/wartezeiten/appres/rest/waz?lang=en") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://www.frankfurt-airport.com/en.html", forHTTPHeaderField: "Referer")
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
        let payload = try decoder.decode(FRAQueueResponse.self, from: data)

        let rows: [WaitTimeEstimate] = payload.data.compactMap { item in
            guard item.kat.lowercased() == "security checkpoint" else { return nil }

            let parsed = parseStatus(item.status)
            let title = checkpointTitle(for: item)

            return WaitTimeEstimate(
                airport: .fra,
                terminal: terminalNumber(for: item.t),
                queueType: .general,
                minutes: parsed.minutes,
                observedAt: Self.isoDateFormatter.date(from: item.lu) ?? Date(),
                checkpointName: title,
                areaName: "Terminal",
                sourceType: .live,
                isClosed: parsed.isClosed
            )
        }

        return rows.sorted {
            ($0.checkpointName ?? "") < ($1.checkpointName ?? "")
        }
    }

    private func terminalNumber(for terminalCode: String) -> Int? {
        Int(terminalCode)
    }

    private func checkpointTitle(for item: FRAQueueItem) -> String {
        let ps = item.ps.trimmingCharacters(in: .whitespacesAndNewlines)
        let concourse = item.h.trimmingCharacters(in: .whitespacesAndNewlines)

        if !ps.isEmpty {
            let firstLine = ps.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ps

            if firstLine.lowercased().contains("transfer security checkpoint") {
                return "Transfer Security \(concourse)"
            }

            if firstLine.lowercased().contains("security checkpoint") || firstLine.lowercased().contains("security checkpoint,") {
                return firstLine
                    .replacingOccurrences(of: "Security checkpoint, ", with: "")
                    .replacingOccurrences(of: "Security Checkpoint, ", with: "")
                    .replacingOccurrences(of: "Security checkpoint ", with: "")
                    .replacingOccurrences(of: "Security Checkpoint ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
                    ? "Security \(concourse)"
                    : firstLine
            }

            return firstLine
        }

        if item.id.contains("ZKS") {
            return "Security \(concourse)"
        }

        if item.id.contains("TKS") {
            return "Transfer Security \(concourse)"
        }

        return "Security \(concourse)"
    }

    private func parseStatus(_ status: String) -> (minutes: Int, isClosed: Bool) {
        let lower = status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if lower == "closed" {
            return (0, true)
        }

        let digits = lower.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        if let value = Int(digits) {
            return (value, false)
        }

        return (0, false)
    }

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()
}

private struct FRAQueueResponse: Decodable {
    let data: [FRAQueueItem]
    let lu: String
    let version: String
}

private struct FRAQueueItem: Decodable {
    let st: String
    let ps: String
    let t: String
    let e: Int
    let h: String
    let lu: String
    let id: String
    let status: String
    let kat: String
}
