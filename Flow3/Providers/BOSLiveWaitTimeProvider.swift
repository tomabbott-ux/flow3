import Foundation

struct BOSLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case invalidURL
        case invalidResponse
        case badHTTPStatus(Int)
        case emptyData
    }

    private let session: URLSession

    private let slug = "tSTQVPRW1"
    private let domainSlug = "BOS"
    private let token = "9uBjlxUu2dTQydGHYGtoDYxH5TE0vHOl"

    private let journeys: [(id: String, name: String)] = [
        ("t6CQ1P0Y3", "Checkpoint 1: A Gates"),
        ("tKK3PDVP9", "Checkpoint 2: A Gates PreCheck Only"),
        ("tXT4B8KMX", "Checkpoint 3: Gates B1 - B22"),
        ("tF1JP9828", "Checkpoint 4: Gates B23 - 40"),
        ("tSGV88H0D", "Checkpoint 5: Terminal C"),
        ("tWEBCSW2Q", "Checkpoint 6: All E Gates"),
        ("tCLRGFHM9", "Checkpoint 7: All E Gates")
    ]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .bos else {
            throw ProviderError.emptyData
        }

        var allResults: [WaitTimeEstimate] = []

        for journey in journeys {
            do {
                let rows = try await fetchJourney(journeyID: journey.id, checkpointName: journey.name)
                allResults.append(contentsOf: rows)
            } catch {
                print("BOS journey failed:", journey.name, error.localizedDescription)
            }
        }

        guard !allResults.isEmpty else {
            throw ProviderError.emptyData
        }

        return allResults.sorted {
            let left = ($0.checkpointName ?? "") + "\($0.queueType)"
            let right = ($1.checkpointName ?? "") + "\($1.queueType)"
            return left < right
        }
    }

    private func fetchJourney(
        journeyID: String,
        checkpointName: String
    ) async throws -> [WaitTimeEstimate] {

        let input = """
        {"0":{"journey":"\(journeyID)","slug":"\(slug)","domainSlug":"\(domainSlug)","token":"\(token)"}}
        """

        guard let encodedInput = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://embed.zensors.live/api/embeddable-widget/trpc/waitTimeExplorer.update?batch=1&input=\(encodedInput)") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://embed.zensors.live/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.2 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode([BOSZensorsUpdateResponse].self, from: data)

        guard let paths = decoded.first?.result.data.paths else {
            throw ProviderError.emptyData
        }

        let now = Date()
        var results: [WaitTimeEstimate] = []

        if let standard = paths.standard {
            results.append(
                WaitTimeEstimate(
                    airport: .bos,
                    terminal: nil,
                    queueType: .general,
                    minutes: roundedMinutes(from: standard.waitTime.value),
                    observedAt: observedDate(from: standard.waitTime.timestamp) ?? now,
                    checkpointName: checkpointName,
                    areaName: "Standard",
                    sourceType: .live,
                    isClosed: !standard.open
                )
            )
        }

        if let precheck = paths.precheck {
            results.append(
                WaitTimeEstimate(
                    airport: .bos,
                    terminal: nil,
                    queueType: .precheck,
                    minutes: roundedMinutes(from: precheck.waitTime.value),
                    observedAt: observedDate(from: precheck.waitTime.timestamp) ?? now,
                    checkpointName: checkpointName,
                    areaName: "TSA PreCheck®",
                    sourceType: .live,
                    isClosed: !precheck.open
                )
            )
        }

        return results
    }

    private func roundedMinutes(from value: Double) -> Int {
        max(0, Int(round(value)))
    }

    private func observedDate(from timestamp: Double) -> Date? {
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp / 1000.0)
    }
}

private struct BOSZensorsUpdateResponse: Decodable {
    let result: BOSZensorsUpdateResult
}

private struct BOSZensorsUpdateResult: Decodable {
    let data: BOSZensorsUpdateData
}

private struct BOSZensorsUpdateData: Decodable {
    let paths: BOSZensorsPaths
}

private struct BOSZensorsPaths: Decodable {
    let precheck: BOSZensorsPath?
    let standard: BOSZensorsPath?
}

private struct BOSZensorsPath: Decodable {
    let name: String
    let verified: Bool
    let open: Bool
    let waitTime: BOSZensorsWaitTime
}

private struct BOSZensorsWaitTime: Decodable {
    let timestamp: Double
    let value: Double
}
