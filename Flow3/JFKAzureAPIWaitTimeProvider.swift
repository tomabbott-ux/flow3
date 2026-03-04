import Foundation

/// ✅ JFK live wait-times provider using the SAME API the website calls.
/// API:
/// https://avi-prod-mpp-webapp-api.azurewebsites.net/api/v1/SecurityWaitTimesPoints/JFK
///
/// IMPORTANT:
/// This API can intermittently return 401 unless you "warm" the session (cookie) first.
/// We do that by loading https://www.jfkairport.com/ once before hitting the API.
///
/// Mapping:
/// - queueType "Reg"    => General
/// - queueType "TSAPre" => PreCheck
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

        print("🚨 JFKAzureAPIWaitTimeProvider CALLED")

        // 1) Warmup (helps prevent intermittent 401)
        try? await warmup()

        // 2) Fetch API JSON
        let data = try await fetchAPIData()

        // 3) Decode rows
        let rows: [JFKRow]
        do {
            rows = try JSONDecoder().decode([JFKRow].self, from: data)
        } catch {
            print("❌ Decode error: \(error)")
            throw ProviderError.decodeFailed
        }

        // ---- SANITY PRINTS (raw uniques) ----
        let uniqueQT = Set(rows.compactMap { $0.queueType?.trimmingCharacters(in: .whitespacesAndNewlines) }).sorted()
        let uniqueCP = Set(rows.compactMap { $0.checkPoint?.trimmingCharacters(in: .whitespacesAndNewlines) }).sorted()
        print("🧩 Unique queueType values: \(uniqueQT)")
        print("🧭 Unique checkPoint values: \(uniqueCP)")
        // -------------------------------------

        // 4) Filter to match website table
        //
        // ✅ KEY CHANGE:
        // Allow "No Wait" rows through even if isWaitTimeAvailable is false.
        // (Website shows "No Wait", API often sets isWaitTimeAvailable=false with timeInMinutes=0.)
        var usable: [JFKRow] = []

        for r in rows {
            guard let terminal = r.terminalInt else { continue }
            guard let minutes = r.timeInMinutes else { continue }

            // Only Security/TSA rows (or if area missing, keep)
            let areaOK = (r.area ?? "").uppercased().contains("TSA") || r.area == nil
            if !areaOK { continue }

            // Only main checkpoint (matches website table)
            if let cp = r.checkPoint?.lowercased(), !cp.contains("main") { continue }

            // Keep if "available" OR if it's a 0-minute row (No Wait)
            let availableOrNoWait = (r.isWaitTimeAvailable == true) || (minutes == 0)
            if !availableOrNoWait {
                // Debug: show what we'd have dropped (especially TSAPre on T1/T7)
                if (r.queueType ?? "").lowercased() == "tsapre" {
                    print("🗑️ Dropped TSAPre row (not available & not 0): T\(terminal) min=\(minutes) avail=\(String(describing: r.isWaitTimeAvailable)) status=\(r.status ?? "nil") queueOpen=\(String(describing: r.queueOpen))")
                }
                continue
            }

            // Prefer status Open, BUT allow 0-minute rows regardless
            let statusOK = (r.status ?? "").lowercased() == "open" || r.status == nil
            if !(statusOK || minutes == 0) { continue }

            usable.append(r)
        }

        if usable.isEmpty {
            print("⚠️ No usable rows after filtering. Raw count: \(rows.count)")
            throw ProviderError.noUsableRows
        }

        // 5) Group by terminal + queue type
        var byTerminal: [Int: (general: Int?, precheck: Int?)] = [:]

        for r in usable {
            guard let terminal = r.terminalInt else { continue }
            guard let minutes = r.timeInMinutes else { continue }

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

        // 6) Build WaitTimeEstimate list
        let now = Date()
        var results: [WaitTimeEstimate] = []

        for terminal in byTerminal.keys.sorted() {
            let v = byTerminal[terminal]!

            if let g = v.general {
                results.append(
                    WaitTimeEstimate(
                        airport: .jfk,
                        terminal: terminal,
                        queueType: .general,
                        minutes: max(0, g),
                        observedAt: now
                    )
                )
            }

            if let p = v.precheck {
                results.append(
                    WaitTimeEstimate(
                        airport: .jfk,
                        terminal: terminal,
                        queueType: .precheck,
                        minutes: max(0, p),
                        observedAt: now
                    )
                )
            }
        }

        // ---- DEBUG: show what's missing per terminal ----
        for terminal in byTerminal.keys.sorted() {
            let v = byTerminal[terminal]!
            let g = v.general.map(String.init) ?? "nil"
            let p = v.precheck.map(String.init) ?? "nil"
            print("🔎 Terminal \(terminal) -> Reg:\(g) TSAPre:\(p)")
        }
        // -----------------------------------------------

        print("✅ Parsed \(results.count) wait-time entries")

        if results.isEmpty {
            throw ProviderError.noUsableRows
        }

        return results
    }

    // MARK: - Networking

    private func warmup() async throws {
        var warmReq = URLRequest(url: warmupURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        warmReq.httpMethod = "GET"
        warmReq.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        warmReq.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        warmReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15", forHTTPHeaderField: "User-Agent")

        let (_, resp) = try await session.data(for: warmReq)
        if let http = resp as? HTTPURLResponse {
            print("🍪 Warmup status: \(http.statusCode)")
        }
    }

    private func fetchAPIData() async throws -> Data {
        print("🌐 Starting request… \(apiURL.absoluteString)")

        var apiReq = URLRequest(url: apiURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        apiReq.httpMethod = "GET"

        // Browser-like headers
        apiReq.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        apiReq.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        apiReq.setValue("https://www.jfkairport.com", forHTTPHeaderField: "Origin")
        apiReq.setValue("https://www.jfkairport.com/", forHTTPHeaderField: "Referer")
        apiReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await session.data(for: apiReq)

        guard let http = resp as? HTTPURLResponse else {
            throw ProviderError.badHTTPStatus(-1)
        }

        print("✅ HTTP status: \(http.statusCode)")

        guard (200..<300).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        if let s = String(data: data, encoding: .utf8) {
            let preview = String(s.prefix(400))
            print("📦 Body preview (first 400 chars):\n\(preview)")
        }

        return data
    }

    // MARK: - Mapping

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

// MARK: - Row model (matches the JSON you pasted)

private struct JFKRow: Decodable {
    let pointID: Int?
    let timeInSeconds: Int?
    let title: String?
    let timeInMinutes: Int?
    let passengerCount: Int?
    let area: String?
    let gate: String?
    let terminal: String?
    let checkPoint: String?
    let queueType: String?
    let queueOpen: Bool?
    let updateTime: String?
    let isWaitTimeAvailable: Bool?
    let status: String?
    let updateTimeText: String?
    let updateDateTimeText: String?

    var terminalInt: Int? {
        if let t = terminal?.trimmingCharacters(in: .whitespacesAndNewlines),
           let n = Int(t) {
            return n
        }
        if let s = title {
            let digits = s.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return Int(digits)
        }
        return nil
    }
}
