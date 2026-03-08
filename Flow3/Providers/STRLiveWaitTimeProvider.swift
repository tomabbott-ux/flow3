import Foundation

final class STRLiveWaitTimeProvider: WaitTimeProviding {
    
    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
        case missingWaitTime
    }
    
    private let session: URLSession
    private let apiURL = URL(string: "https://www.stuttgart-airport.com/en/ajax/info-widget/waiting-times")!
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .str else { return [] }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("https://www.stuttgart-airport.com/en/travellers-visitors", forHTTPHeaderField: "Referer")
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
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw ProviderError.invalidResponse
        }
        
        let points = try parsePoints(from: html)
        
        return points.map { point in
            WaitTimeEstimate(
                airport: .str,
                terminal: point.terminal,
                queueType: .general,
                minutes: point.minutes,
                observedAt: Date(),
                checkpointName: "Security",
                areaName: "Terminal \(point.terminal)",
                sourceType: .live,
                isClosed: point.isClosed
            )
        }
    }
    
    private func parsePoints(from html: String) throws -> [(terminal: Int, minutes: Int, isClosed: Bool)] {
        let itemPattern = #"<li>[\s\S]*?<span class="waiting-times__terminal--short">T(\d+):</span>[\s\S]*?<span class="waiting-times__minutes(?:\s+waiting-times__minutes--closed)?">\s*([^<]+?)\s*</span>[\s\S]*?</li>"#
        
        guard let itemRegex = try? NSRegularExpression(
            pattern: itemPattern,
            options: [.caseInsensitive]
        ) else {
            throw ProviderError.invalidResponse
        }
        
        let htmlRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = itemRegex.matches(in: html, options: [], range: htmlRange)
        
        var results: [(Int, Int, Bool)] = []
        
        for match in matches {
            guard
                let terminalRange = Range(match.range(at: 1), in: html),
                let valueRange = Range(match.range(at: 2), in: html),
                let terminal = Int(html[terminalRange])
            else {
                continue
            }
            
            let rawValue = html[valueRange]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            
            if rawValue.contains("closed") {
                results.append((terminal: terminal, minutes: 0, isClosed: true))
                continue
            }
            
            let minutePattern = #"(\d+)\s*minutes?"#
            guard let minuteRegex = try? NSRegularExpression(
                pattern: minutePattern,
                options: [.caseInsensitive]
            ) else {
                continue
            }
            
            let valueRangeNS = NSRange(rawValue.startIndex..<rawValue.endIndex, in: rawValue)
            
            if let minuteMatch = minuteRegex.firstMatch(in: rawValue, options: [], range: valueRangeNS),
               let minuteRange = Range(minuteMatch.range(at: 1), in: rawValue),
               let minutes = Int(rawValue[minuteRange]) {
                results.append((terminal: terminal, minutes: minutes, isClosed: false))
            }
        }
        
        guard !results.isEmpty else {
            throw ProviderError.missingWaitTime
        }
        
        return results.sorted(by: { $0.0 < $1.0 })
        
    }
}
