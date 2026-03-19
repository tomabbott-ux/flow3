import Foundation
import WebKit

@MainActor
final class ATLWebViewFetcher: NSObject, WKNavigationDelegate {

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<String, Error>?
    private var timeoutTask: Task<Void, Never>?

    func fetchHTML(from url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let config = WKWebViewConfiguration()
            config.websiteDataStore = .default()

            let webView = WKWebView(frame: .zero, configuration: config)
            webView.navigationDelegate = self
            webView.isHidden = true
            self.webView = webView

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("text/html, */*; q=0.01", forHTTPHeaderField: "Accept")
            request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            request.setValue("https://www.atl.com/times/", forHTTPHeaderField: "Referer")
            request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
                forHTTPHeaderField: "User-Agent"
            )

            webView.load(request)

            self.timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard let self else { return }
                guard let continuation = self.continuation else { return }

                self.continuation = nil
                self.webView?.navigationDelegate = nil
                self.webView = nil

                continuation.resume(throwing: URLError(.timedOut))
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.documentElement.outerHTML.toString()") { [weak self] result, error in
            guard let self else { return }
            guard let continuation = self.continuation else { return }

            self.timeoutTask?.cancel()
            self.continuation = nil
            self.webView?.navigationDelegate = nil
            self.webView = nil

            if let error {
                continuation.resume(throwing: error)
                return
            }

            if let html = result as? String, !html.isEmpty {
                continuation.resume(returning: html)
            } else {
                continuation.resume(throwing: URLError(.cannotDecodeContentData))
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    private func fail(_ error: Error) {
        guard let continuation = continuation else { return }

        timeoutTask?.cancel()
        self.continuation = nil
        webView?.navigationDelegate = nil
        webView = nil

        continuation.resume(throwing: error)
    }
}
