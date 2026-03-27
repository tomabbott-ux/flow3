import Foundation

final class DELLiveWaitTimeProvider: WaitTimeProviding {

    private let t2URL = URL(string: "https://www.newdelhiairport.in/dial-api/wait-time/T2?places=T2")!
    private let t3URL = URL(string: "https://www.newdelhiairport.in/dial-api/wait-time?places=T3%20Entrance")!

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        async let t2RowsTask: [WaitTimeEstimate] = safeFetchT2Rows(for: airport)
        async let t3RowsTask: [WaitTimeEstimate] = safeFetchT3Rows(for: airport)

        let t2Rows = await t2RowsTask
        let t3Rows = await t3RowsTask

        let results = t2Rows + t3Rows

        var seen = Set<String>()
        let deduped = results.filter { item in
            let key = [
                item.airport.rawValue,
                "\(item.terminal ?? -1)",
                item.checkpointName ?? "",
                item.areaName ?? "",
                item.queueType.rawValue,
                "\(item.minutes)"
            ].joined(separator: "|")

            return seen.insert(key).inserted
        }

        return deduped.sorted {
            if ($0.terminal ?? 0) != ($1.terminal ?? 0) {
                return ($0.terminal ?? 0) < ($1.terminal ?? 0)
            }
            return ($0.checkpointName ?? "") < ($1.checkpointName ?? "")
        }
    }

    // MARK: - Safe wrappers

    private func safeFetchT2Rows(for airport: FlowAirport) async -> [WaitTimeEstimate] {
        do {
            return try await fetchT2Rows(for: airport)
        } catch {
            print("DEL T2 fetch failed:", error.localizedDescription)
            return []
        }
    }

    private func safeFetchT3Rows(for airport: FlowAirport) async -> [WaitTimeEstimate] {
        do {
            return try await fetchT3Rows(for: airport)
        } catch {
            print("DEL T3 fetch failed:", error.localizedDescription)
            return []
        }
    }

    // MARK: - T2

    private func fetchT2Rows(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        let request = makeRequest(url: t2URL)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        let payload = try decoder.decode(DELT2Response.self, from: data)

        guard payload.status else { return [] }

        let observedAt = Date()
        var rows: [WaitTimeEstimate] = []

        for item in payload.data.En ?? [] {
            if let minutes = midpointMinutes(from: item.waiting_time) {
                rows.append(
                    WaitTimeEstimate(
                        airport: airport,
                        terminal: 2,
                        queueType: .general,
                        minutes: minutes,
                        observedAt: observedAt,
                        checkpointName: "Gate \(normalizedGate(item.queueId))",
                        areaName: "Terminal 2",
                        sourceType: .live,
                        isClosed: false
                    )
                )
            }
        }

        for item in payload.data.Security ?? [] {
            if let minutes = midpointMinutes(from: item.waiting_time) {
                rows.append(
                    WaitTimeEstimate(
                        airport: airport,
                        terminal: 2,
                        queueType: .general,
                        minutes: minutes,
                        observedAt: observedAt,
                        checkpointName: item.queueId,
                        areaName: "Terminal 2 Security",
                        sourceType: .live,
                        isClosed: false
                    )
                )
            }
        }

        for item in payload.data.D2D ?? [] {
            if let minutes = midpointMinutes(from: item.waiting_time) {
                rows.append(
                    WaitTimeEstimate(
                        airport: airport,
                        terminal: 2,
                        queueType: .general,
                        minutes: minutes,
                        observedAt: observedAt,
                        checkpointName: item.queueId,
                        areaName: "Terminal 2 D2D",
                        sourceType: .live,
                        isClosed: false
                    )
                )
            }
        }

        return rows
    }

    // MARK: - T3

    private func fetchT3Rows(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        let request = makeRequest(url: t3URL)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        let payload = try decoder.decode(DELT3Response.self, from: data)

        guard payload.status else { return [] }

        let observedAt = Date()

        return payload.waiting_time.compactMap { item in
            guard let minutes = midpointMinutes(from: item.waiting_time) else {
                return nil
            }

            return WaitTimeEstimate(
                airport: airport,
                terminal: 3,
                queueType: .general,
                minutes: minutes,
                observedAt: observedAt,
                checkpointName: "Gate \(normalizedGate(item.entry_gate))",
                areaName: "Terminal 3",
                sourceType: .live,
                isClosed: false
            )
        }
    }

    // MARK: - Helpers

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://www.newdelhiairport.in/wait-time/", forHTTPHeaderField: "Referer")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    private func midpointMinutes(from text: String) -> Int? {
        let cleaned = text
            .replacingOccurrences(of: "minutes", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = cleaned
            .components(separatedBy: "-")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard let low = Int(parts.first ?? "") else { return nil }
        let high = Int(parts.dropFirst().first ?? "") ?? low

        return max(0, (low + high) / 2)
    }

    private func normalizedGate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = trimmed.replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
        return stripped.isEmpty ? trimmed : stripped
    }
}

// MARK: - Models

private struct DELT2Response: Decodable {
    let status: Bool
    let message: String?
    let data: DELT2Data
}

private struct DELT2Data: Decodable {
    let En: [DELT2Queue]?
    let Security: [DELT2Queue]?
    let D2D: [DELT2Queue]?
}

private struct DELT2Queue: Decodable {
    let queueId: String
    let waiting_time: String
}

private struct DELT3Response: Decodable {
    let waiting_time: [DELT3Queue]
    let status: Bool
    let message: String?
}

private struct DELT3Queue: Decodable {
    let entry_gate: String
    let waiting_time: String
}
