import Foundation

struct PendingCalendarFlight: Identifiable, Equatable, Hashable {
    let id: String
    let flightNumber: String
    let title: String
    let routeText: String?
    let departureDate: Date
    let departureAirportCode: String?
    let location: String?
    let notes: String?

    init(
        flightNumber: String,
        title: String,
        routeText: String? = nil,
        departureDate: Date,
        departureAirportCode: String? = nil,
        location: String? = nil,
        notes: String? = nil
    ) {
        self.flightNumber = flightNumber
        self.title = title
        self.routeText = routeText
        self.departureDate = departureDate
        self.departureAirportCode = departureAirportCode
        self.location = location
        self.notes = notes

        let airportPart = departureAirportCode ?? "UNKNOWN"
        self.id = "\(flightNumber)|\(departureDate.timeIntervalSince1970)|\(airportPart)"
    }
}
