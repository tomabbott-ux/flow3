import Foundation

struct AMSWaitTimeProvider: WaitTimeProviding {

    let trackedFlight: TrackedFlight?

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .ams else { return [] }

        print("AMS PROVIDER CALLED")

        // ✅ Use tracked flight if available, otherwise fallback
        let flightCode = trackedFlight?.flightNumber ?? "KL1215"
        let date = currentDateString()

        let urlString = "https://www.schiphol.nl/en/departures/flight/D\(date)\(flightCode)/"
        print("AMS DEBUG urlString:", urlString)

        guard let url = URL(string: urlString) else {
            print("AMS DEBUG invalid URL")
            return []
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let http = response as? HTTPURLResponse {
            print("AMS DEBUG status:", http.statusCode)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            print("AMS DEBUG failed to decode html")
            return []
        }

        // ✅ Extract from visible page text (this works reliably)
        let level = extractCrowdLevelFromVisibleText(html)

        print("AMS DEBUG extracted level:", level ?? "nil")

        guard let level, let minutes = mapCrowdLevelToMinutes(level) else {
            print("AMS PROVIDER returning empty")
            return []
        }

        print("AMS PROVIDER success minutes:", minutes)

        return [
            WaitTimeEstimate(
                airport: .ams,
                terminal: 1,
                queueType: .general,
                minutes: minutes,
                observedAt: Date(),
                checkpointName: "Security",
                sourceType: .live
            )
        ]
    }

    // MARK: - Extract crowd level from visible text

    private func extractCrowdLevelFromVisibleText(_ html: String) -> String? {
        let lower = html.lowercased()

        if lower.contains("less busy") {
            return "LESS_BUSY"
        }

        if lower.contains("very busy") || lower.contains("peak") {
            return "PEAK"
        }

        if lower.contains("busy") {
            return "BUSY"
        }

        return nil
    }

    // MARK: - Map to minutes

    private func mapCrowdLevelToMinutes(_ level: String) -> Int? {
        switch level {
        case "LESS_BUSY": return 5
        case "BUSY": return 20
        case "PEAK": return 40
        default: return nil
        }
    }

    // MARK: - Date

    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return formatter.string(from: Date())
    }
}
