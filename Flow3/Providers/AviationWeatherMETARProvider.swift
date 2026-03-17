import Foundation

final class AviationWeatherMETARProvider: WeatherProviding {

    enum ProviderError: Error {
        case invalidURL
        case invalidResponse
        case noData
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWeather(for airport: FlowAirport) async throws -> WeatherSnapshot {

        let icao = airport.icaoCode

        guard let url = URL(
            string: "https://aviationweather.gov/api/data/metar?ids=\(icao)&format=json&hours=1"
        ) else {
            throw ProviderError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            throw ProviderError.invalidResponse
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
            let first = json.first
        else {
            throw ProviderError.noData
        }

        let tempDouble = first["temp"] as? Double
        let tempC = Int(round(tempDouble ?? 0))

        let summary = decodeWeatherSummary(from: first) ?? "Clear skies"

        return WeatherSnapshot(
            airport: airport,
            temperatureC: tempC,
            summary: summary,
            observedAt: Date()
        )
    }

    // MARK: - Weather decoding

    private func decodeWeatherSummary(from metar: [String: Any]) -> String? {

        let weather = nonEmptyString(metar["wxString"])?.uppercased()
        let cover = nonEmptyString(metar["cover"])?.uppercased()
        let rawOb = nonEmptyString(metar["rawOb"])?.uppercased()

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

    private func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
