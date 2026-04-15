import Foundation

enum FreeAirportConfig {

    static let freeAirports: Set<String> = [
        "iah",
        "ord",
        "ist",
        "ams",
        "bcn",
        "lga"
    ]

    static let fallbackFreeAirportCode = "lax"

    static func isFreeAirport(code: String) -> Bool {
        freeAirports.contains(code.lowercased())
    }
}
