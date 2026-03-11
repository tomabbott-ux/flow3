import Foundation

struct LiveMETARWeatherProvider: WeatherProviding {

    func fetchWeather(for airport: FlowAirport) async throws -> WeatherSnapshot {

        let icao = airport.icaoCode

        guard let url = URL(
            string: "https://aviationweather.gov/api/data/metar?ids=\(icao)&format=json"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("FlowApp/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
            let metar = json.first
        else {
            throw URLError(.cannotParseResponse)
        }

        let temperature = parseTemperature(metar)
        let summary = parseSummary(metar)

        return WeatherSnapshot(
            airport: airport,
            temperatureC: temperature,
            summary: summary,
            observedAt: Date()
        )
    }

    private func parseTemperature(_ json: [String: Any]) -> Int {

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

    private func parseSummary(_ json: [String: Any]) -> String {

        if let wx = json["wxString"] as? String, !wx.isEmpty {
            return decodeMETARWeatherString(wx)
        }

        if let clouds = json["clouds"] as? [[String: Any]],
           let cover = clouds.first?["cover"] as? String {

            switch cover {
            case "CLR", "SKC": return "Clear"
            case "FEW": return "Few clouds"
            case "SCT": return "Scattered clouds"
            case "BKN": return "Broken clouds"
            case "OVC": return "Overcast"
            default: return cover
            }
        }

        return "Clear"
    }

    private func decodeMETARWeatherString(_ raw: String) -> String {

        let cleaned = raw
            .replacingOccurrences(of: "+", with: " heavy ")
            .replacingOccurrences(of: "-", with: " light ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        let replacements: [(String, String)] = [
            ("TSRA", "Thunderstorm with rain"),
            ("TS", "Thunderstorm"),
            ("SHRA", "Rain showers"),
            ("DZ", "Drizzle"),
            ("RA", "Rain"),
            ("SN", "Snow"),
            ("PL", "Ice pellets"),
            ("GR", "Hail"),
            ("BR", "Mist"),
            ("FG", "Fog"),
            ("HZ", "Haze"),
            ("FU", "Smoke"),
            ("SQ", "Squalls")
        ]

        var result = cleaned

        for (code, text) in replacements.sorted(by: { $0.0.count > $1.0.count }) {
            result = result.replacingOccurrences(of: code, with: text)
        }

        result = result
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized

        return result.isEmpty ? "Clear" : result
    }
}
