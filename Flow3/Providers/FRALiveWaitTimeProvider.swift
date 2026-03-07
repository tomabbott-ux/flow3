import Foundation

final class FRALiveWaitTimeProvider: NSObject, WaitTimeProviding, URLSessionDelegate {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
    }

    private let apiURL = URL(string: "https://www.frankfurt-airport.com/wartezeiten/appres/rest/waz?lang=en")!
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .fra else { return [] }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.frankfurt-airport.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.frankfurt-airport.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(FRAResponse.self, from: data)

        var estimates: [WaitTimeEstimate] = []

        for item in decoded.data {
            guard item.kat.lowercased().contains("security") else { continue }
            guard let minutes = parseMinutes(from: item.status) else { continue }

            estimates.append(
                WaitTimeEstimate(
                    airport: .fra,
                    terminal: terminalNumber(from: item.h),
                    queueType: .general,
                    minutes: minutes,
                    observedAt: parseObservedAt(item.lu) ?? Date(),
                    checkpointName: checkpointName(from: item.ps),
                    areaName: areaName(from: item.ps),
                    sourceType: .live
                )
            )
        }

        return estimates
    }

    private func parseMinutes(from status: String) -> Int? {
        let lower = status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if lower.contains("closed") {
            return nil
        }

        if lower.contains("no wait") {
            return 0
        }

        let numbers = lower.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }

        if let first = numbers.first {
            return first
        }

        return nil
    }

    private func terminalNumber(from hall: String) -> Int? {
        switch hall.uppercased() {
        case "A", "B", "C":
            return 1
        case "D", "E":
            return 2
        default:
            return nil
        }
    }

    private func checkpointName(from description: String) -> String {
        if description.contains("Concourse A") { return "Concourse A" }
        if description.contains("Concourse B") { return "Concourse B" }
        if description.contains("Concourse C") { return "Concourse C" }
        if description.contains("D / E") || description.contains("D/E") { return "Concourse D / E" }
        if description.contains("Gates D1-4") { return "Gates D1-4" }
        if description.contains("Gates D5-8") { return "Gates D5-8" }
        if description.contains("Gates E2-5") { return "Gates E2-5" }
        if description.contains("Gates E6-9") { return "Gates E6-9" }
        return "Security"
    }

    private func areaName(from description: String) -> String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Security" }
        if let firstLine = trimmed.components(separatedBy: .newlines).first {
            return firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Security"
    }

    private func parseObservedAt(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter.date(from: value)
    }

    // DEV-ONLY trust bypass for FRA endpoint
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

private struct FRAResponse: Decodable {
    let data: [FRAItem]
    let lu: String?
    let version: String?
}

private struct FRAItem: Decodable {
    let st: String
    let ps: String
    let t: String
    let e: Int?
    let h: String
    let lu: String
    let id: String
    let status: String
    let kat: String
}
