import Foundation

enum BoardingSignalLevel {
    case none
    case headToTerminal
    case gateAssigned
    case boardingLikelySoon
    case finalCall
}

struct BoardingSignal {
    let level: BoardingSignalLevel
    let title: String
    let subtitle: String
}

extension FlightLookupResult {

    func boardingSignal(now: Date = Date()) -> BoardingSignal {
        let cleanedStatus = normalizedStatus(status)
        let hasTerminal = !(terminal?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasGate = !(gate?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        let minutesToDeparture = Int(departureTime.timeIntervalSince(now) / 60)

        if isFinalCallStatus(cleanedStatus) {
            return BoardingSignal(
                level: .finalCall,
                title: "Final call",
                subtitle: gateLine(prefix: "Proceed immediately")
            )
        }

        if isBoardingStatus(cleanedStatus) {
            return BoardingSignal(
                level: .boardingLikelySoon,
                title: "Boarding",
                subtitle: gateLine(prefix: "Go to gate")
            )
        }

        if hasGate && minutesToDeparture <= 20 {
            return BoardingSignal(
                level: .boardingLikelySoon,
                title: "Boarding likely soon",
                subtitle: gateLine(prefix: "Gate assigned")
            )
        }

        if hasGate && minutesToDeparture <= 45 {
            return BoardingSignal(
                level: .gateAssigned,
                title: "Gate assigned",
                subtitle: gateLine(prefix: "Head to gate")
            )
        }

        if hasTerminal && minutesToDeparture <= 60 {
            return BoardingSignal(
                level: .headToTerminal,
                title: "Head to terminal",
                subtitle: terminalLine(prefix: "Prepare for security")
            )
        }

        return BoardingSignal(
            level: .none,
            title: "Awaiting gate",
            subtitle: fallbackLine()
        )
    }

    private func normalizedStatus(_ raw: String?) -> String {
        raw?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private func isBoardingStatus(_ status: String) -> Bool {
        status.contains("boarding") ||
        status.contains("gate open")
    }

    private func isFinalCallStatus(_ status: String) -> Bool {
        status.contains("final call") ||
        status.contains("last call")
    }

    private func gateLine(prefix: String) -> String {
        let cleanGate = gate?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTerminal = terminal?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let terminal = cleanTerminal, !terminal.isEmpty,
           let gate = cleanGate, !gate.isEmpty {
            return "\(prefix) • T\(terminal) • Gate \(gate)"
        }

        if let gate = cleanGate, !gate.isEmpty {
            return "\(prefix) • Gate \(gate)"
        }

        if let terminal = cleanTerminal, !terminal.isEmpty {
            return "\(prefix) • T\(terminal)"
        }

        return prefix
    }

    private func terminalLine(prefix: String) -> String {
        let cleanTerminal = terminal?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let terminal = cleanTerminal, !terminal.isEmpty {
            return "\(prefix) • T\(terminal)"
        }

        return prefix
    }

    private func fallbackLine() -> String {
        let cleanStatus = status?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let cleanStatus, !cleanStatus.isEmpty {
            return cleanStatus
        }

        return "No gate published yet"
    }
}
