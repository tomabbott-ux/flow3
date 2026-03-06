import Foundation

struct StubWeatherProvider: WeatherProviding {

    func fetchWeather(for airport: FlowAirport) async throws -> WeatherSnapshot {
        let now = Date()

        switch airport {

        case .atl:
            return WeatherSnapshot(
                airport: .atl,
                temperatureC: 26,
                summary: "Sunny",
                observedAt: now
            )

        case .jfk:
            return WeatherSnapshot(
                airport: .jfk,
                temperatureC: 22,
                summary: "Cloudy",
                observedAt: now
            )

        case .lhr:
            return WeatherSnapshot(
                airport: .lhr,
                temperatureC: 18,
                summary: "Rain",
                observedAt: now
            )

        case .yyz:
            return WeatherSnapshot(
                airport: .yyz,
                temperatureC: -2,
                summary: "Snow",
                observedAt: now
            )

        default:
            return WeatherSnapshot(
                airport: airport,
                temperatureC: 24,
                summary: "Clear",
                observedAt: now
            )
        }
    }
}
