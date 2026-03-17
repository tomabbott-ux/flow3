import Foundation

final class TSAGenericWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
        case invalidJSON
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard let url = URL(string: "https://tsawaittimes.com/api/airport/\(airport.rawValue)") else {
            throw ProviderError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
            forHTTPHeaderField: "User-Agent"
        )

        request.setValue(
            "application/json, text/plain, */*",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        print("🌐 TSA API \(airport.rawValue) status:", http.statusCode)

        guard (200...299).contains(http.statusCode) else {
            if let raw = String(data: data, encoding: .utf8) {
                print("❌ TSA API \(airport.rawValue) raw error body:", raw)
            }
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        if let raw = String(data: data, encoding: .utf8) {
            print("📦 TSA API \(airport.rawValue) raw body:", raw)
        }

        let jsonObject = try JSONSerialization.jsonObject(with: data)

        guard let root = jsonObject as? [String: Any] else {
            throw ProviderError.invalidJSON
        }

        let now = Date()

        let airportName =
            firstNonEmptyString([
                root["name"],
                root["airport_name"],
                root["airportName"],
                root["title"]
            ]) ?? airport.displayName

        let waitMinutes =
            firstInt([
                root["rightnow"],
                root["right_now"],
                root["current_wait"],
                root["currentWait"],
                root["wait_time"],
                root["waitTime"],
                root["minutes"]
            ])
            ?? firstEstimatedHourlyWait(from: root)
            ?? firstNestedInt(in: root)

        guard let minutes = waitMinutes else {
            print("⚠️ TSA API \(airport.rawValue): no wait minutes found")
            return []
        }

        print("✅ TSA API \(airport.rawValue): parsed minutes =", minutes)

        return [
            WaitTimeEstimate(
                airport: airport,
                terminal: nil,
                queueType: .general,
                minutes: max(0, minutes),
                observedAt: now,
                checkpointName: "Security",
                areaName: airportName,
                sourceType: .estimated
            )
        ]
    }

    private func firstEstimatedHourlyWait(from root: [String: Any]) -> Int? {

        if let slots = root["estimated_hourly_times"] as? [[String: Any]] {
            for slot in slots {
                if let value = firstInt([
                    slot["waittime"],
                    slot["wait_time"],
                    slot["minutes"]
                ]) {
                    return value
                }
            }
        }

        if let slots = root["estimatedHourlyTimes"] as? [[String: Any]] {
            for slot in slots {
                if let value = firstInt([
                    slot["waittime"],
                    slot["wait_time"],
                    slot["minutes"]
                ]) {
                    return value
                }
            }
        }

        return nil
    }

    private func firstNestedInt(in dictionary: [String: Any]) -> Int? {
        for (_, value) in dictionary {

            if let intValue = value as? Int {
                return intValue
            }

            if let doubleValue = value as? Double {
                return Int(doubleValue.rounded())
            }

            if let stringValue = value as? String {
                let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

                if let intValue = Int(trimmed) {
                    return intValue
                }

                if let doubleValue = Double(trimmed) {
                    return Int(doubleValue.rounded())
                }
            }

            if let nested = value as? [String: Any],
               let found = firstNestedInt(in: nested) {
                return found
            }

            if let array = value as? [[String: Any]] {
                for item in array {
                    if let found = firstNestedInt(in: item) {
                        return found
                    }
                }
            }
        }

        return nil
    }

    private func firstInt(_ values: [Any?]) -> Int? {
        for value in values {

            if let intValue = value as? Int {
                return intValue
            }

            if let doubleValue = value as? Double {
                return Int(doubleValue.rounded())
            }

            if let stringValue = value as? String {
                let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

                if let intValue = Int(trimmed) {
                    return intValue
                }

                if let doubleValue = Double(trimmed) {
                    return Int(doubleValue.rounded())
                }
            }
        }

        return nil
    }

    private func firstNonEmptyString(_ values: [Any?]) -> String? {
        for value in values {
            if let stringValue = value as? String {
                let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }

        return nil
    }
}
