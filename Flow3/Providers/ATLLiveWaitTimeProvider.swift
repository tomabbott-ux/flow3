import Foundation

struct ATLLiveWaitTimeProvider {

    private let wpJSON = URL(string: "https://www.atl.com/wp-json/wp/v2/pages/15191")!
    private let htmlURL = URL(string: "https://www.atl.com/times/")!

    func fetch() async throws -> [ATLSecurityCheckpointWait] {

        // 1️⃣ Try WordPress JSON endpoint first
        if let html = try? await fetchATLHTMLFromWPJSON() {

            // 🔎 DEBUG LINE (Step 2)
            print("ATL raw contains DOMESTIC?", html.uppercased().contains("DOMESTIC"), "length:", html.count)

            let parsed = ATLSecurityWaitTimesParser.parse(html: html)
            if !parsed.isEmpty { return parsed }
        }

        // 2️⃣ Fallback to the normal HTML page
        let html = try await fetchString(url: htmlURL, accept: "text/html, */*; q=0.01")

        // 🔎 DEBUG LINE (Step 2)
        print("ATL raw contains DOMESTIC?", html.uppercased().contains("DOMESTIC"), "length:", html.count)

        let parsed = ATLSecurityWaitTimesParser.parse(html: html)
        return parsed
    }

    // MARK: - Private

    private func fetchATLHTMLFromWPJSON() async throws -> String {
        let data = try await fetchData(url: wpJSON, accept: "application/json")
        let decoded = try JSONDecoder().decode(WPPage.self, from: data)

        // WordPress stores HTML inside content.rendered
        return decoded.content.rendered
    }

    private func fetchString(url: URL, accept: String) async throws -> String {
        let data = try await fetchData(url: url, accept: accept)

        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }

        throw URLError(.cannotDecodeRawData)
    }

    private func fetchData(url: URL, accept: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(accept, forHTTPHeaderField: "Accept")

        // Pretend to be Safari to avoid bot filtering
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        return data
    }
}

// MARK: - WordPress JSON model
private struct WPPage: Decodable {

    struct Content: Decodable {
        let rendered: String
    }

    let content: Content
}
