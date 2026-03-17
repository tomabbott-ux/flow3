import Foundation

private struct PITWaitItem: Decodable {
    let canDisplayData: Bool
    let checkpointId: String
    let checkpointName: String
    let queueId: String
    let queueName: String
    let status: String
    let waitTime: Int
}

struct PITLiveWaitTimeProvider: WaitTimeProviding {

    // Replace the value below with your PIT subscription key from the browser request header
    private let subscriptionKey = "PASTE_YOUR_PIT_SUBSCRIPTION_KEY_HERE"

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .pit else { return [] }

        let url = URL(string: "https://acaa-dna-api-prod.azure-api.net/tsa/wait-times")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // ✅ REQUIRED headers (all of them)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("92cd43f60453443098d08528bf0c994e", forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("https://flypittsburgh.com", forHTTPHeaderField: "Origin")
        request.setValue("https://flypittsburgh.com/", forHTTPHeaderField: "Referer")

        // Optional but helps mimic browser
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
            forHTTPHeaderField: "User-Agent"
        )
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode([PITWaitItem].self, from: data)
        let now = Date()

        let visible = decoded.filter { $0.canDisplayData }

        let standard = visible.first {
            $0.queueName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "standard"
        }

        let precheck = visible.first {
            $0.queueName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "precheck"
        }

        var results: [WaitTimeEstimate] = []

        if let standard {
            results.append(
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .general,
                    minutes: max(0, standard.waitTime),
                    observedAt: now,
                    checkpointName: standard.checkpointName,
                    areaName: standard.status,
                    sourceType: .live,
                    isClosed: standard.status.lowercased() != "open"
                )
            )
        }

        if let precheck {
            results.append(
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .precheck,
                    minutes: max(0, precheck.waitTime),
                    observedAt: now,
                    checkpointName: precheck.checkpointName,
                    areaName: precheck.status,
                    sourceType: .live,
                    isClosed: precheck.status.lowercased() != "open"
                )
            )
        }
        func displayText(for minutes: Int) -> String {
            if minutes <= 0 { return "No wait" }
            if minutes == 1 { return "1 min" }
            return "\(minutes) min"
        }
        return results
    }
}
