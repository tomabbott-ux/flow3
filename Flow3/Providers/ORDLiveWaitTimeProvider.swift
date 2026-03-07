import Foundation

final class ORDLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
    }

    private let session: URLSession
    private let apiURL = URL(string: "https://tsawaittimes.flychicago.com/tsawaittimes")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .ord else { return [] }

        let data = try await fetchAPIData()

        let rows: [ORDRow]
        do {
            rows = try JSONDecoder().decode([ORDRow].self, from: data)
        } catch {
            throw ProviderError.invalidResponse
        }

        var byTerminal: [Int: (general: Int?, precheck: Int?)] = [:]

        for row in rows {
            let lower = row.name.lowercased()

            // Only ORD terminal rows
            guard lower.contains("ord.t") else { continue }

            // Ignore placeholder/sentinel values
            guard row.waitTimes >= 0, row.waitTimes < 10_000 else { continue }

            guard let terminal = extractTerminal(from: lower) else { continue }

            let minutes = max(0, Int((row.waitTimes / 60.0).rounded()))

            if isPrecheckRow(lower) {
                var existing = byTerminal[terminal] ?? (general: nil, precheck: nil)
                existing.precheck = best(existing.precheck, minutes)
                byTerminal[terminal] = existing
                continue
            }

            if isGeneralRow(lower) {
                var existing = byTerminal[terminal] ?? (general: nil, precheck: nil)
                existing.general = best(existing.general, minutes)
                byTerminal[terminal] = existing
                continue
            }

            // Fallback: some ORD feeds expose total/overview wait rather than explicit general
            if isTotalOrOverviewRow(lower) {
                var existing = byTerminal[terminal] ?? (general: nil, precheck: nil)
                existing.general = best(existing.general, minutes)
                byTerminal[terminal] = existing
            }
        }

        let now = Date()
        var results: [WaitTimeEstimate] = []

        for terminal in byTerminal.keys.sorted() {
            let values = byTerminal[terminal]!

            if let g = values.general {
                results.append(
                    WaitTimeEstimate(
                        airport: .ord,
                        terminal: terminal,
                        queueType: .general,
                        minutes: g,
                        observedAt: now,
                        checkpointName: "Security",
                        sourceType: .live
                    )
                )
            }

            if let p = values.precheck {
                results.append(
                    WaitTimeEstimate(
                        airport: .ord,
                        terminal: terminal,
                        queueType: .precheck,
                        minutes: p,
                        observedAt: now,
                        checkpointName: "Security",
                        sourceType: .live
                    )
                )
            }
        }

        return results
    }

    private func fetchAPIData() async throws -> Data {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.flychicago.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.flychicago.com/", forHTTPHeaderField: "Referer")
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

        return data
    }

    private func extractTerminal(from name: String) -> Int? {
        guard let range = name.range(of: "ord.t") else { return nil }

        let idx = range.upperBound
        guard idx < name.endIndex else { return nil }

        return Int(String(name[idx]))
    }

    private func isPrecheckRow(_ name: String) -> Bool {
        name.contains("precheck")
            || name.contains("precheckqueue")
            || name.contains("precheckqueueprojqt")
    }

    private func isGeneralRow(_ name: String) -> Bool {
        name.contains("general")
            || name.contains("generalqueue")
            || name.contains("generalqueueprojqt")
    }

    private func isTotalOrOverviewRow(_ name: String) -> Bool {
        name.contains("totalwaittime")
            || name.contains("overview")
            || name.contains("waittime.projectedqueuetime")
    }

    private func best(_ current: Int?, _ candidate: Int) -> Int {
        guard let current else { return candidate }
        return min(current, candidate)
    }
}

private struct ORDRow: Decodable {
    let id: Int
    let name: String
    let waitTimes: Double
    let t: String
}
