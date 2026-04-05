import Foundation

final class AviationWeatherMETARProvider: WeatherProviding {

    enum ProviderError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case requestFailed(statusCode: Int)
        case malformedData

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid weather URL"
            case .invalidResponse:
                return "Invalid weather response"
            case .requestFailed(let statusCode):
                return "Weather request failed with status \(statusCode)"
            case .malformedData:
                return "Weather data was malformed"
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWeather(for airport: FlowAirport) async throws -> WeatherSnapshot {

        let icao = airport.icaoCode.uppercased()

        guard let url = URL(
            string: "https://aviationweather.gov/api/data/metar?ids=\(icao)&format=json&hours=1"
        ) else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "Flow/1.0 (iOS Weather Fetch)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            break

        case 204:
            return fallbackSnapshot(for: airport)

        default:
            throw ProviderError.requestFailed(statusCode: http.statusCode)
        }

        guard !data.isEmpty else {
            return fallbackSnapshot(for: airport)
        }

        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])

        guard let array = jsonObject as? [[String: Any]] else {
            throw ProviderError.malformedData
        }

        guard let first = array.first else {
            return fallbackSnapshot(for: airport)
        }

        let temperatureC = extractTemperatureC(from: first)
        let summary = decodeWeatherSummary(from: first) ?? "Weather unavailable"

        return WeatherSnapshot(
            airport: airport,
            temperatureC: temperatureC,
            summary: summary,
            observedAt: Date()
        )
    }

    // MARK: - Temperature decoding

    private func extractTemperatureC(from metar: [String: Any]) -> Int {

        if let value = doubleValue(forKeys: ["temp"], in: metar) {
            return Int(round(value))
        }

        if let value = doubleValue(forKeys: ["tempC"], in: metar) {
            return Int(round(value))
        }

        if let value = doubleValue(forKeys: ["temperature"], in: metar) {
            return Int(round(value))
        }

        return 0
    }

    // MARK: - Weather decoding

    private func decodeWeatherSummary(from metar: [String: Any]) -> String? {

        let weather = firstNonEmptyString(
            forKeys: ["wxString", "wx"],
            in: metar
        )?.uppercased()

        let cover = firstCloudCover(in: metar)?.uppercased()

        let rawOb = firstNonEmptyString(
            forKeys: ["rawOb", "raw_text", "rawText"],
            in: metar
        )?.uppercased()

        if let rawOb, rawOb.contains("CAVOK") {
            return "Clear skies"
        }

        if let weather {
            switch weather {

            case "CAVOK":
                return "Clear skies"

            case "VCSH":
                return "Showers nearby"

            case "SHRA":
                return "Rain showers"

            case "RA":
                return "Rain"

            case "-RA":
                return "Light rain"

            case "+RA":
                return "Heavy rain"

            case "TS":
                return "Thunderstorms"

            case "TSRA":
                return "Thunderstorms with rain"

            case "VCTS":
                return "Thunderstorms nearby"

            case "BR":
                return "Mist"

            case "FG":
                return "Fog"

            case "HZ":
                return "Haze"

            case "SN":
                return "Snow"

            case "SHSN":
                return "Snow showers"

            case "DZ":
                return "Drizzle"

            case "-DZ":
                return "Light drizzle"

            case "+DZ":
                return "Heavy drizzle"

            default:
                break
            }
        }

        switch cover {
        case "CLR", "SKC":
            return "Clear skies"
        case "FEW":
            return "Few clouds"
        case "SCT":
            return "Scattered clouds"
        case "BKN":
            return "Broken clouds"
        case "OVC":
            return "Overcast"
        case .none:
            return nil
        default:
            return cover
        }
    }

    // MARK: - Helpers

    private func fallbackSnapshot(for airport: FlowAirport) -> WeatherSnapshot {
        WeatherSnapshot(
            airport: airport,
            temperatureC: 0,
            summary: "Weather unavailable",
            observedAt: Date()
        )
    }

    private func firstNonEmptyString(
        forKeys keys: [String],
        in dictionary: [String: Any]
    ) -> String? {
        for key in keys {
            if let value = nonEmptyString(dictionary[key]) {
                return value
            }
        }
        return nil
    }

    private func doubleValue(
        forKeys keys: [String],
        in dictionary: [String: Any]
    ) -> Double? {
        for key in keys {
            if let value = dictionary[key] as? Double {
                return value
            }
            if let value = dictionary[key] as? Int {
                return Double(value)
            }
            if let value = dictionary[key] as? String,
               let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }
        }
        return nil
    }

    private func firstCloudCover(in metar: [String: Any]) -> String? {

        if let cover = nonEmptyString(metar["cover"]) {
            return cover
        }

        if let clouds = metar["clouds"] as? [[String: Any]] {
            for cloud in clouds {
                if let cover = nonEmptyString(cloud["cover"]) {
                    return cover
                }
            }
        }

        if let cloudLayers = metar["cloudLayers"] as? [[String: Any]] {
            for cloud in cloudLayers {
                if let cover = nonEmptyString(cloud["cover"]) {
                    return cover
                }
            }
        }

        return nil
    }

    private func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
