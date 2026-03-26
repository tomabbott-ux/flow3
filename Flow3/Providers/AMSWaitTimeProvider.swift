import Foundation

struct AMSWaitTimeProvider: WaitTimeProviding {

    let trackedFlight: TrackedFlight?

    private static let cache = AMSWaitTimeCache()

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .ams else { return [] }

        if let cached = await Self.cache.get() {
            print("AMS CACHE HIT")
            return cached
        }

        print("AMS PROVIDER CALLED")

        let candidates = try await buildCandidateFlights()
        print("AMS DEBUG candidate count:", candidates.count)

        var seenFlightCodes = Set<String>()
        var resultsByTerminal: [Int: WaitTimeEstimate] = [:]

        for candidate in candidates {
            let normalizedCode = candidate.flightCode
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .uppercased()

            guard !normalizedCode.isEmpty else { continue }
            guard !seenFlightCodes.contains(normalizedCode) else { continue }

            seenFlightCodes.insert(normalizedCode)

            do {
                if let scraped = try await scrapeFlightPage(for: candidate) {
                    let terminalValue: Int = scraped.terminal ?? candidate.terminal ?? 1

                    guard resultsByTerminal[terminalValue] == nil else { continue }

                    let estimate = WaitTimeEstimate(
                        airport: .ams,
                        terminal: terminalValue,
                        queueType: .general,
                        minutes: scraped.minutes,
                        observedAt: Date(),
                        checkpointName: "Security",
                        sourceType: .live
                    )

                    resultsByTerminal[terminalValue] = estimate
                    print("AMS DEBUG added terminal:", terminalValue, "minutes:", scraped.minutes)

                    if resultsByTerminal.count >= 3 {
                        break
                    }
                }
            } catch {
                print("AMS DEBUG scrape failed:", error.localizedDescription)
                continue
            }
        }

        let results = resultsByTerminal.values.sorted {
            ($0.terminal ?? 999) < ($1.terminal ?? 999)
        }

        if results.isEmpty {
            print("AMS PROVIDER returning empty")
            return []
        }

        await Self.cache.set(results)
        print("AMS PROVIDER success terminals:", results.map { $0.terminal ?? -1 })
        return results
    }

    // MARK: - Build Candidates

    private func buildCandidateFlights() async throws -> [AMSResolvedFlight] {
        var candidates: [AMSResolvedFlight] = []

        if let tracked = trackedFlight?.flightNumber,
           !tracked.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            candidates.append(
                AMSResolvedFlight(
                    flightCode: tracked,
                    pageDateString: currentPageDateString(),
                    terminal: nil
                )
            )
        }

        let apiFlights = try await fetchTerminalCandidatesFromAPI()
        candidates.append(contentsOf: apiFlights)

        if candidates.isEmpty {
            candidates.append(
                AMSResolvedFlight(
                    flightCode: "KL1215",
                    pageDateString: currentPageDateString(),
                    terminal: 1
                )
            )
        }

        return candidates
    }

    private func fetchTerminalCandidatesFromAPI() async throws -> [AMSResolvedFlight] {
        var allFlights: [AMSFlight] = []

        // Search wider across multiple pages
        for page in 0...5 {
            let pageFlights = try await fetchFlightsPage(page: page)
            print("AMS API page \(page) flights:", pageFlights.count)
            allFlights.append(contentsOf: pageFlights)
        }

        // Keep several candidates per terminal/hall so scraping has options
        var results: [AMSResolvedFlight] = []
        var terminalCounts: [Int: Int] = [:]

        for flight in allFlights {
            guard flight.flightDirection == "D" else { continue }
            guard let terminal = flight.terminal else { continue }
            guard !flight.mainFlight.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else { continue }

            let currentCount = terminalCounts[terminal] ?? 0
            guard currentCount < 4 else { continue }

            terminalCounts[terminal] = currentCount + 1

            results.append(
                AMSResolvedFlight(
                    flightCode: flight.mainFlight,
                    pageDateString: flight.scheduleDate.replacingOccurrences(of: "-", with: ""),
                    terminal: terminal
                )
            )
        }

        print("AMS API terminals found:", terminalCounts.keys.sorted())
        return results
    }

    private func fetchFlightsPage(page: Int) async throws -> [AMSFlight] {
        var components = URLComponents(string: "\(SchipholAPIConfig.baseURL)/flights")
        components?.queryItems = [
            URLQueryItem(name: "scheduleDate", value: currentAPIDateString()),
            URLQueryItem(name: "flightDirection", value: "D"),
            URLQueryItem(name: "includedelays", value: "false"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort", value: "scheduleTime")
        ]

        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue(SchipholAPIConfig.appID, forHTTPHeaderField: "app_id")
        request.setValue(SchipholAPIConfig.appKey, forHTTPHeaderField: "app_key")
        request.setValue(SchipholAPIConfig.resourceVersion, forHTTPHeaderField: "ResourceVersion")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse {
            print("AMS API status page \(page):", http.statusCode)
        }

        let decoded = try JSONDecoder().decode(AMSFlightsResponse.self, from: data)
        return decoded.flights
    }

    // MARK: - Scraping

    private func scrapeFlightPage(for flight: AMSResolvedFlight) async throws -> AMSScrapedWait? {
        let urlString = "https://www.schiphol.nl/en/departures/flight/D\(flight.pageDateString)\(flight.flightCode)/"

        guard let url = URL(string: urlString) else { return nil }

        let (data, _) = try await URLSession.shared.data(from: url)

        guard let html = String(data: data, encoding: .utf8) else { return nil }

        let level = extractCrowdLevel(html)
        let terminal = extractTerminal(html) ?? flight.terminal

        guard let level, let minutes = map(level) else { return nil }

        return AMSScrapedWait(minutes: minutes, terminal: terminal)
    }

    private func extractCrowdLevel(_ html: String) -> String? {
        let lower = html.lowercased()

        if lower.contains("less busy") { return "LESS_BUSY" }
        if lower.contains("very busy") || lower.contains("peak") { return "PEAK" }
        if lower.contains("busy") { return "BUSY" }

        return nil
    }

    private func extractTerminal(_ html: String) -> Int? {
        let patterns = [
            #"Terminal (\d+)"#,
            #"terminal (\d+)"#,
            #"departure hall (\d+)"#,
            #"Departure hall (\d+)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return Int(html[range])
            }
        }

        return nil
    }

    private func map(_ level: String) -> Int? {
        switch level {
        case "LESS_BUSY": return 5
        case "BUSY": return 20
        case "PEAK": return 40
        default: return nil
        }
    }

    // MARK: - Dates

    private func currentAPIDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return f.string(from: Date())
    }

    private func currentPageDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return f.string(from: Date())
    }
}

// MARK: - Cache

actor AMSWaitTimeCache {
    private var cached: [WaitTimeEstimate]?
    private var timestamp: Date?

    func get() -> [WaitTimeEstimate]? {
        guard let cached, let timestamp else { return nil }
        guard Date().timeIntervalSince(timestamp) < 60 else { return nil }
        return cached
    }

    func set(_ data: [WaitTimeEstimate]) {
        cached = data
        timestamp = Date()
    }
}

// MARK: - Models

private struct AMSResolvedFlight {
    let flightCode: String
    let pageDateString: String
    let terminal: Int?
}

private struct AMSScrapedWait {
    let minutes: Int
    let terminal: Int?
}

private struct AMSFlightsResponse: Decodable {
    let flights: [AMSFlight]
}

private struct AMSFlight: Decodable {
    let flightDirection: String
    let mainFlight: String
    let scheduleDate: String
    let terminal: Int?
}
