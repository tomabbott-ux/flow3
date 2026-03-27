import Foundation

struct AirportTerminalFormatter {

    static func displayName(for airport: FlowAirport, rawTerminal: String?) -> String {
        guard let rawTerminal else { return "TBD" }

        let trimmed = rawTerminal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "TBD" }

        let upper = trimmed.uppercased()

        switch airport {

        case .atl:
            if upper == "N" || upper == "NORTH" {
                return "North"
            }

            if upper == "S" || upper == "SOUTH" {
                return "South"
            }

            if upper == "MAIN" || upper == "M" {
                return "Main"
            }

            if upper == "1" || upper == "DOMESTIC" || upper == "D" || upper.contains("DOM") {
                return "Domestic"
            }

            if upper == "2" || upper == "INTERNATIONAL" || upper == "I" || upper.contains("INT") {
                return "International"
            }

            return trimmed.capitalized

        default:
            if upper == "TBD" {
                return "TBD"
            }

            if upper.hasPrefix("TERMINAL ") {
                return trimmed
            }

            if upper.hasPrefix("T") {
                return trimmed
            }

            return "Terminal \(trimmed)"
        }
    }

    static func compactName(for airport: FlowAirport, rawTerminal: String?) -> String {
        displayName(for: airport, rawTerminal: rawTerminal)
    }
}
