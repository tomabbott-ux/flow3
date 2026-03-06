import Foundation

final class JFKAzureAPIWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case decodeFailed
        case noUsableRows
    }

    private let session: URLSession
    private let warmupURL = URL(string: "https://www.jfkairport.com/")!
    private let apiURL = URL(string: "https://avi-prod-mpp-webapp-api.azurewebsites.net/api/v1/SecurityWaitTimesPoints/JFK")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .jfk else { return [] }

        try? await warmup()
        let data = try await fetchAPIData()

        let rows: [JFKRow]
        do {
            rows = try JSONDecoder().decode([JFKRow].self, from: data)
        } catch {
            throw ProviderError.decodeFailed
        }

        var byTerminal: [Int: (general: Int?, precheck: Int?)] = [:]

        for r in rows {
            guard let terminal = r.terminalInt else { continue }
            guard let minutes = r.timeInMinutes else { continue }

            let areaOK = (r.area ?? "").uppercased().contains("TSA") || r.area == nil
            if !areaOK { continue }

            if let cp = r.checkPoint?.lowercased(), !cp.contains("main") { continue }

            let availableOrNoWait = (r.isWaitTimeAvailable == true) || (minutes == 0)
            if !availableOrNoWait { continue }

            let statusOK = (r.status ?? "").lowercased() == "open" || r.status == nil
            if !(statusOK || minutes == 0) { continue }

            switch mapQueueType(r.queueType) {
            case .general:
                var existing = byTerminal[terminal] ?? (general: nil, precheck: nil)
                existing.general = minutes
                byTerminal[terminal] = existing

            case .precheck:
                var existing = byTerminal[terminal] ?? (general: nil, precheck: nil)
                existing.precheck = minutes
                byTerminal[terminal] = existing

            case .unknown:
                continue
            }
        }

        if byTerminal.isEmpty {
            throw ProviderError.noUsableRows
        }

        let now = Date()
        var results: [WaitTimeEstimate] = []

        for terminal in byTerminal.keys.sorted() {
            let values = byTerminal[terminal]!

            if let g = values.general {
                results.append(
                    WaitTimeEstimate(
                        airport: .jfk,
                        terminal: terminal,
                        queueType: .general,
                        minutes: g,
                        observedAt: now,
                        checkpointName: "Main Checkpoint",
                        sourceType: .live
                    )
                )
            }

            if let p = values.precheck {
                results.append(
                    WaitTimeEstimate(
                        airport: .jfk,
                        terminal: terminal,
                        queueType: .precheck,
                        minutes: p,
                        observedAt: now,
                        checkpointName: "Main Checkpoint",
                        sourceType: .live
                    )
                )
            }
        }

        return results
    }

    private func warmup() async throws {
        var request = URLRequest(url: warmupURL)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        _ = try await session.data(for: request)
    }

    private func fetchAPIData() async throws -> Data {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.jfkairport.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.badHTTPStatus(-1)
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        return data
    }

    private enum MappedQueue {
        case general
        case precheck
        case unknown
    }

    private func mapQueueType(_ raw: String?) -> MappedQueue {
        let q = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if q == "reg" { return .general }
        if q == "tsapre" { return .precheck }
        if q.contains("regular") || q.contains("general") { return .general }
        if q.contains("pre") || q.contains("tsa") { return .precheck }

        return .unknown
    }
}

private struct JFKRow: Decodable {
    let terminal: String?
    let timeInMinutes: Int?
    let queueType: String?
    let checkPoint: String?
    let area: String?
    let status: String?
    let isWaitTimeAvailable: Bool?

    var terminalInt: Int? {
        if let t = terminal,
           let n = Int(t.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return n
        }
        return nil
    }
}
