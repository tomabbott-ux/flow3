import Foundation

protocol WeatherProviding {
    func fetchWeather(for airport: FlowAirport) async throws -> WeatherSnapshot
}

final class WeatherService {

    private let provider: WeatherProviding

    init(provider: WeatherProviding) {
        self.provider = provider
    }

    func fetchWeather(for airport: FlowAirport) async throws -> WeatherSnapshot {
        try await provider.fetchWeather(for: airport)
    }
}
