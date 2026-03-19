import Foundation

struct ATLLiveWaitTimeProvider {

    private let wpJSON = URL(string: "https://www.atl.com/wp-json/wp/v2/pages/15191")!
    private let htmlURL = URL(string: "https://www.atl.com/times/")!

    func fetch() async throws -> [ATLSecurityCheckpointWait] {

        // 1. Try direct HTML request first
        if let html = try? await fetchString(
            url: htmlURL,
            accept: "text/html, */*; q=0.01",
            referer: "https://www.atl.com/times/"
        ) {
            print("ATL raw contains DOMESTIC?", html.uppercased().contains("DOMESTIC"), "length:", html.count)

            let parsed = ATLSecurityWaitTimesParser.parse(html: html)
            if !parsed.isEmpty {
                return parsed
            }
        }

        // 2. Try WordPress JSON
        if let html = try? await fetchATLHTMLFromWPJSON() {
            print("ATL raw contains DOMESTIC?", html.uppercased().contains("DOMESTIC"), "length:", html.count)

            let parsed = ATLSecurityWaitTimesParser.parse(html: html)
            if !parsed.isEmpty {
                return parsed
            }
        }

        // 3. If blocked or empty, return [] so caller can gracefully fallback
        print("ATL blocked or empty on all routes — returning empty")
        return []
    }

    // MARK: - Private

    private func fetchATLHTMLFromWPJSON() async throws -> String {
        let data = try await fetchData(
            url: wpJSON,
            accept: "application/json, text/plain, */*",
            referer: "https://www.atl.com/times/"
        )

        let decoded = try JSONDecoder().decode(WPPage.self, from: data)
        return decoded.content.rendered
    }

    private func fetchString(url: URL, accept: String, referer: String) async throws -> String {
        let data = try await fetchData(url: url, accept: accept, referer: referer)

        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }

        throw URLError(.cannotDecodeRawData)
    }

    private func fetchData(url: URL, accept: String, referer: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData

        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.waitsForConnectivity = false

        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(http.statusCode) else {
            let bodyPreview = String(data: data.prefix(300), encoding: .utf8) ?? "<non-utf8>"
            print("ATL fetch failed:", http.statusCode, "url:", url.absoluteString)
            print("ATL body preview:", bodyPreview)
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
