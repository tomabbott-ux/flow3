import Foundation

struct DOHLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case invalidURL
        case badHTTPStatus(Int)
        case invalidResponse
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard airport == .doh else { return [] }

        guard let url = URL(string: "https://dohahamadairport.com/webservices/xovis?summary=true") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://dohahamadairport.com/", forHTTPHeaderField: "Referer")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Self.dateFormatter)

        let payload = try decoder.decode(DOHQueueResponse.self, from: data)

        let rows = payload.checkpoints.compactMap { checkpoint -> WaitTimeEstimate? in
            guard let firstQueue = checkpoint.queues.first else { return nil }

            let mapped = mapCheckpoint(checkpoint, queue: firstQueue)
            guard mapped.include else { return nil }

            let liveMinutes = max(0, firstQueue.waitTime)
            let fallbackMinutes = max(0, firstQueue.projectedWaitTime)
            let finalMinutes = liveMinutes > 0 ? liveMinutes : fallbackMinutes

            return WaitTimeEstimate(
                airport: .doh,
                terminal: nil,
                queueType: .general,
                minutes: finalMinutes,
                observedAt: firstQueue.lastMeasured,
                checkpointName: mapped.title,
                areaName: mapped.subtitle.isEmpty ? nil : mapped.subtitle,
                sourceType: .live,
                isClosed: false
            )
        }

        return rows.sorted {
            let left = "\($0.checkpointName ?? "") \($0.areaName ?? "")"
            let right = "\($1.checkpointName ?? "") \($1.areaName ?? "")"
            return left < right
        }
    }

    private func mapCheckpoint(_ checkpoint: DOHCheckpoint, queue: DOHQueue) -> (include: Bool, title: String, subtitle: String) {

        let id = checkpoint.checkpointName.lowercased()
        let label = queue.content.queueLabel.en.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if id.contains("departure security") || label == "departure security" {
            return (true, "Departure Security", "")
        }

        if id.contains("place - tsa") || id.contains("transfer_a") || label == "transfers a" {
            return (true, "Transfers A", "")
        }

        if id.contains("place - tsb") || id.contains("transfer_b") || label == "transfers b" {
            return (true, "Transfers B", "")
        }

        if id.contains("transfer c") || id.contains("transfer_c") || label == "transfers c" {
            return (true, "Transfers C", "")
        }

        if id.contains("transfer d") || id.contains("transfer_d") || label == "transfers d" {
            return (true, "Transfers D", "")
        }

        if id.contains("transfer e") || id.contains("transfer_e") || label == "transfers e" {
            return (true, "Transfers E", "")
        }

        return (false, "", "")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Qatar")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

private struct DOHQueueResponse: Decodable {
    let checkpoints: [DOHCheckpoint]
}

private struct DOHCheckpoint: Decodable {
    let checkpointId: Int
    let checkpointName: String
    let queues: [DOHQueue]

    enum CodingKeys: String, CodingKey {
        case checkpointId = "checkpoint_id"
        case checkpointName = "checkpoint_name"
        case queues
    }
}

private struct DOHQueue: Decodable {
    let queueId: Int
    let queueName: String
    let waitTime: Int
    let projectedWaitTime: Int
    let throughput: Int
    let occupancy: Int
    let content: DOHQueueContent
    let lastMeasured: Date

    enum CodingKeys: String, CodingKey {
        case queueId = "queue_id"
        case queueName = "queue_name"
        case waitTime = "wait_time"
        case projectedWaitTime = "projected_wait_time"
        case throughput
        case occupancy
        case content
        case lastMeasured = "last_measured"
    }
}

private struct DOHQueueContent: Decodable {
    let imageUrl: String
    let imageLabel: DOHLocalizedText
    let queueLabel: DOHLocalizedText

    enum CodingKeys: String, CodingKey {
        case imageUrl
        case imageLabel
        case queueLabel
    }
}

private struct DOHLocalizedText: Decodable {
    let en: String
    let ar: String
}
