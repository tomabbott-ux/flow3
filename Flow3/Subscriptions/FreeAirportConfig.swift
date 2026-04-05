import Foundation

enum FreeAirportConfig {

    static let freeAirports: Set<String> = [
        "lax",
        "ord",
        "ist",
        "ams",
        "lga"
    ]

    static let fallbackFreeAirportCode = "lax"

    static func isFreeAirport(code: String) -> Bool {
        freeAirports.contains(code.lowercased())
    }
}
