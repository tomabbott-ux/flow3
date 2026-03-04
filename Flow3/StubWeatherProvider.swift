import Foundation

struct StubWeatherProvider: WeatherProviding {

    func fetchWeather(for airport: FlowAirport) async throws -> WeatherSnapshot {

        let now = Date()

        switch airport {

        case .atl:
            return WeatherSnapshot(
                airport: .atl,
                temperatureC: 18,
                summary: "Clear",
                observedAt: now
            )

        case .jfk:
            return WeatherSnapshot(
                airport: .jfk,
                temperatureC: 9,
                summary: "Windy",
                observedAt: now
            )

        case .lhr:
            return WeatherSnapshot(
                airport: .lhr,
                temperatureC: 7,
                summary: "Cloudy",
                observedAt: now
            )
        }
    }
}
