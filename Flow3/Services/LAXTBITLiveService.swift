import Foundation

struct LAXTBITLiveRow: Equatable {
    let terminalLabel: String
    let boardingType: String
    let minutes: Int
}

enum LAXTBITLiveServiceError: LocalizedError {
    case invalidURL
    case invalidHTML
    case noTBITRowsFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid LAX wait-times URL."
        case .invalidHTML:
            return "Could not parse LAX wait-times HTML."
        case .noTBITRowsFound:
            return "No TBIT rows found on the LAX wait-times page."
        }
    }
}

final class LAXTBITLiveService {

    private let session: URLSession
    private let pageURLString = "https://www.flylax.com/wait-times"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchLiveTBITEstimates() async throws -> [WaitTimeEstimate] {
        let rows = try await fetchTBITRows()
        return makeWaitTimeEstimates(from: rows)
    }

    func mergeTBITLiveIntoExistingLAXFeed(
        existing: [WaitTimeEstimate]
    ) async -> [WaitTimeEstimate] {
        do {
            let liveTBIT = try await fetchLiveTBITEstimates()
            return merged(existing: existing, liveTBIT: liveTBIT)
        } catch {
            print("LAX TBIT live scrape failed, keeping estimated LAX feed:", error.localizedDescription)
            return existing
        }
    }

    func fetchTBITRows() async throws -> [LAXTBITLiveRow] {
        guard let url = URL(string: pageURLString) else {
            throw LAXTBITLiveServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8),
              !html.isEmpty else {
            throw LAXTBITLiveServiceError.invalidHTML
        }

        let rows = parseTBITRows(from: html)

        guard !rows.isEmpty else {
            throw LAXTBITLiveServiceError.noTBITRowsFound
        }

        return rows
    }

    func parseTBITRows(from html: String) -> [LAXTBITLiveRow] {
        let normalized = html
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")

        let rowPattern = #"<tr[^>]*>\s*<td[^>]*>(.*?)</td>\s*<td[^>]*>(.*?)</td>\s*<td[^>]*>(.*?)</td>\s*</tr>"#

        guard let regex = try? NSRegularExpression(
            pattern: rowPattern,
            options: [.caseInsensitive]
        ) else {
            return []
        }

        let nsRange = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        let matches = regex.matches(in: normalized, options: [], range: nsRange)

        var parsed: [LAXTBITLiveRow] = []

        for match in matches {
            guard match.numberOfRanges == 4,
                  let terminalRange = Range(match.range(at: 1), in: normalized),
                  let boardingTypeRange = Range(match.range(at: 2), in: normalized),
                  let waitTimeRange = Range(match.range(at: 3), in: normalized) else {
                continue
            }

            let terminalRaw = stripHTML(String(normalized[terminalRange]))
            let boardingTypeRaw = stripHTML(String(normalized[boardingTypeRange]))
            let waitTimeRaw = stripHTML(String(normalized[waitTimeRange]))

            let terminal = clean(terminalRaw)
            let boardingType = clean(boardingTypeRaw)

            guard isTBIT(terminal),
                  let minutes = parseMinutes(from: waitTimeRaw) else {
                continue
            }

            parsed.append(
                LAXTBITLiveRow(
                    terminalLabel: terminal,
                    boardingType: boardingType,
                    minutes: minutes
                )
            )
        }

        return parsed
    }

    func makeWaitTimeEstimates(from rows: [LAXTBITLiveRow]) -> [WaitTimeEstimate] {
        let observedAt = Date()
        var output: [WaitTimeEstimate] = []

        if let generalMinutes = rows
            .filter({ isGeneral($0.boardingType) })
            .map(\.minutes)
            .min() {

            output.append(
                WaitTimeEstimate(
                    airport: .lax,
                    terminal: 0,
                    queueType: .general,
                    minutes: generalMinutes,
                    observedAt: observedAt,
                    checkpointName: "TBIT",
                    areaName: "General Boarding",
                    sourceType: .live,
                    isClosed: false
                )
            )
        }

        if let precheckMinutes = rows
            .filter({ isPreCheck($0.boardingType) })
            .map(\.minutes)
            .min() {

            output.append(
                WaitTimeEstimate(
                    airport: .lax,
                    terminal: nil,
                    queueType: .precheck,
                    minutes: precheckMinutes,
                    observedAt: observedAt,
                    checkpointName: "TBIT",
                    areaName: "TSA PreCheck",
                    sourceType: .live,
                    isClosed: false
                )
            )
        }

        return output
    }

    func merged(
        existing: [WaitTimeEstimate],
        liveTBIT: [WaitTimeEstimate]
    ) -> [WaitTimeEstimate] {
        let filteredExisting = existing.filter { estimate in
            guard estimate.airport == .lax else { return true }

            let checkpoint = (estimate.checkpointName ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let area = (estimate.areaName ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let isTBITCheckpoint = checkpoint == "tbit"
                || checkpoint.contains("tom bradley")
                || checkpoint.contains("international")

            let isMatchingQueue =
                (estimate.queueType == .general && area.contains("general")) ||
                (estimate.queueType == .precheck && (area.contains("precheck") || area.contains("pre-check")))

            if isTBITCheckpoint && isMatchingQueue {
                return false
            }

            return true
        }

        return filteredExisting + liveTBIT
    }

    private func stripHTML(_ value: String) -> String {
        value.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
    }

    private func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#160;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseMinutes(from value: String) -> Int? {
        let cleaned = clean(value).lowercased()

        if cleaned.contains("no wait") {
            return 0
        }

        if let range = cleaned.range(of: #"(\d+)"#, options: .regularExpression) {
            return Int(cleaned[range])
        }

        return nil
    }

    private func isTBIT(_ terminal: String) -> Bool {
        let normalized = terminal.lowercased()
        return normalized == "tbit"
            || normalized.contains("tom bradley")
            || normalized.contains("tom bradley international")
    }

    private func isGeneral(_ boardingType: String) -> Bool {
        let normalized = boardingType.lowercased()
        return normalized.contains("general")
    }

    private func isPreCheck(_ boardingType: String) -> Bool {
        let normalized = boardingType.lowercased()
        return normalized.contains("precheck") || normalized.contains("pre-check")
    }
}
