import Foundation

final class AviationWeatherMETARProvider: WeatherProviding {

    enum ProviderError: Error {
        case invalidURL
        case badHTTPStatus(Int)
        case invalidResponse
        case noData
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWeather(for airport: FlowAirport) async throws -> WeatherSnapshot {

        let icao = airport.icaoCode

        guard let url = URL(string: "https://aviationweather.gov/api/data/metar?ids=\(icao)&format=json") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "FlowApp/1.0 (airport weather using METAR; contact: app)",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
            let first = root.first
        else {
            throw ProviderError.noData
        }

        let temperatureC = parseTemperature(from: first)
        let summary = buildSummary(from: first)
        let observedAt = parseObservedAt(from: first) ?? Date()

        return WeatherSnapshot(
            airport: airport,
            temperatureC: temperatureC,
            summary: summary,
            observedAt: observedAt
        )
    }

    private func parseTemperature(from json: [String: Any]) -> Int {
        if let temp = json["temp"] as? Double {
            return Int(temp.rounded())
        }

        if let temp = json["temp"] as? Int {
            return temp
        }

        if let tempString = json["temp"] as? String,
           let temp = Double(tempString) {
            return Int(temp.rounded())
        }

        return 0
    }

    private func parseObservedAt(from json: [String: Any]) -> Date? {
        let candidates = [
            json["obsTime"] as? String,
            json["reportTime"] as? String
        ].compactMap { $0 }

        for candidate in candidates {
            if let date = isoFormatterWithFractional.date(from: candidate) {
                return date
            }
            if let date = isoFormatter.date(from: candidate) {
                return date
            }
        }

        return nil
    }

    private func buildSummary(from json: [String: Any]) -> String {
        let weatherText = nonEmptyString(json["wxString"])
        let flightCategory = nonEmptyString(json["fltCat"])
        let cloudText = parseClouds(from: json)
        let windText = parseWind(from: json)

        let parts = [weatherText, cloudText, windText, flightCategory]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }

        if parts.isEmpty {
            return "METAR"
        }

        return parts.joined(separator: " • ")
    }

    private func parseClouds(from json: [String: Any]) -> String? {
        guard let clouds = json["clouds"] as? [[String: Any]], let first = clouds.first else {
            return nil
        }

        let cover = nonEmptyString(first["cover"])?.uppercased()

        switch cover {
        case "CLR", "SKC": return "Clear"
        case "FEW": return "Few clouds"
        case "SCT": return "Scattered clouds"
        case "BKN": return "Broken clouds"
        case "OVC": return "Overcast"
        case .none:
            return nil
        default:
            return cover
        }
    }

    private func parseWind(from json: [String: Any]) -> String? {
        let speed: Int? = {
            if let value = json["wspd"] as? Int { return value }
            if let value = json["wspd"] as? Double { return Int(value.rounded()) }
            if let value = json["wspd"] as? String, let parsed = Int(value) { return parsed }
            return nil
        }()

        guard let speed else { return nil }

        return speed == 0 ? "Calm" : "Wind \(speed)kt"
    }

    private func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
