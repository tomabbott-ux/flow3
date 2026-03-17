import Foundation

// MARK: - Response Models

private struct CLEWaitResponse: Decodable {
    let field_json: CLEFieldJSON
}

private struct CLEFieldJSON: Decodable {
    let a: String
    let b: String
    let c: String
    let apre: Bool
    let bpre: Bool
    let cpre: Bool
}

// MARK: - Provider

struct CLELiveWaitTimeProvider: WaitTimeProviding {

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard airport == .cle else { return [] }

        let url = URL(string: "https://www.clevelandairport.com/tsa-wait-times-api")!

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode([CLEWaitResponse].self, from: data)

        guard let json = decoded.first?.field_json else { return [] }

        let now = Date()

        return [
            makeEstimate(airport: airport, name: "Checkpoint A", level: json.a, pre: json.apre, date: now),
            makeEstimate(airport: airport, name: "Checkpoint B", level: json.b, pre: json.bpre, date: now),
            makeEstimate(airport: airport, name: "Checkpoint C", level: json.c, pre: json.cpre, date: now)
        ]
    }

    private func makeEstimate(
        airport: FlowAirport,
        name: String,
        level: String,
        pre: Bool,
        date: Date
    ) -> WaitTimeEstimate {

        let minutes: Int
        let label: String

        switch level.lowercased() {
        case "low":
            minutes = 8
            label = pre ? "Low · PreCheck available" : "Low"

        case "medium":
            minutes = 15
            label = pre ? "Medium · PreCheck available" : "Medium"

        case "high":
            minutes = 28
            label = pre ? "High · PreCheck available" : "High"

        default:
            minutes = 10
            label = pre ? "Estimate · PreCheck available" : "Estimate"
        }

        return WaitTimeEstimate(
            airport: airport,
            terminal: nil,
            queueType: .general,
            minutes: minutes,
            observedAt: date,
            checkpointName: name,
            areaName: label,
            sourceType: .live,
            isClosed: false
        )
    }
}
