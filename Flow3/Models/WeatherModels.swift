import Foundation

struct WeatherSnapshot: Codable, Hashable {
    let airport: FlowAirport
    let temperatureC: Int
    let summary: String
    let observedAt: Date

    init(airport: FlowAirport, temperatureC: Int, summary: String, observedAt: Date) {
        self.airport = airport
        self.temperatureC = temperatureC
        self.summary = summary
        self.observedAt = observedAt
    }
}
