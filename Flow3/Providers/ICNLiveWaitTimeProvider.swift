import Foundation

struct ICNLiveWaitTimeProvider: WaitTimeProviding {

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .icn else { return [] }

        let terminal1 = try await fetchCheckpointRows(tmnlId: 1, airport: airport)
        let terminal2 = try await fetchCheckpointRows(tmnlId: 2, airport: airport)

        return terminal1 + terminal2
    }

    private func fetchCheckpointRows(tmnlId: Int, airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard let url = URL(
            string: "https://www.airport.kr/pgn/ap_en/passengerNoticeApiData.do?tmnlId=\(tmnlId)"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let observedAt = Date()

        return json.compactMap { item -> WaitTimeEstimate? in
            guard let gateId = item["gateId"] as? String else {
                return nil
            }

            guard let checkpointName = checkpointName(from: gateId) else {
                return nil
            }

            let gateStatus = (item["gateStts"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let waitString = (item["wtngTm"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            let isClosed = gateStatus == "CL" || gateStatus == "NP" || waitString == "-" || waitString.isEmpty

            let minutes: Int
            if let parsedMinutes = Int(waitString) {
                minutes = parsedMinutes
            } else {
                minutes = 0
            }

            return WaitTimeEstimate(
                airport: airport,
                terminal: tmnlId,
                queueType: .general,
                minutes: minutes,
                observedAt: observedAt,
                checkpointName: checkpointName,
                areaName: "Terminal \(tmnlId)",
                sourceType: .live,
                isClosed: isClosed
            )
        }
    }

    private func checkpointName(from gateId: String) -> String? {
        let cleaned = gateId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard cleaned.hasPrefix("DG") else { return nil }

        let parts = cleaned.split(separator: "_")
        guard let first = parts.first else { return nil }

        let areaNumber = first.replacingOccurrences(of: "DG", with: "")
        guard !areaNumber.isEmpty else { return nil }

        let side: String
        if cleaned.hasSuffix("_E") {
            side = "East"
        } else if cleaned.hasSuffix("_W") {
            side = "West"
        } else {
            side = ""
        }

        return side.isEmpty ? "Area \(areaNumber)" : "Area \(areaNumber) \(side)"
    }
}
