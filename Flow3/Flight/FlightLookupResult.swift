import Foundation

struct FlightLookupResult {
    let flightNumber: String
    let airline: String
    let originIATA: String
    let destinationIATA: String
    let terminal: String?
    let gate: String?
    let status: String?
    let departureTime: Date
}
