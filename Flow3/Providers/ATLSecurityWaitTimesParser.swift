import Foundation

enum ATLTerminal: String, Codable {
    case domestic = "DOMESTIC"
    case international = "INTL"
}

struct ATLSecurityCheckpointWait: Identifiable, Codable, Hashable {
    let id: String
    let terminal: ATLTerminal
    let checkpointName: String
    let minutes: Int

    init(terminal: ATLTerminal, checkpointName: String, minutes: Int) {
        self.terminal = terminal
        self.checkpointName = checkpointName
        self.minutes = minutes
        self.id = "\(terminal.rawValue)-\(checkpointName)".uppercased()
    }
}

enum ATLSecurityWaitTimesParser {

    static func parse(html: String) -> [ATLSecurityCheckpointWait] {
        let text = normalizedText(from: html)

        // We search for each checkpoint label and grab the first number after it.
        // This avoids brittle section slicing (DOMESTIC / INT'L / INT’L etc).
        var results: [ATLSecurityCheckpointWait] = []

        if let m = firstMinutes(afterAnyOf: ["DOMESTIC MAIN CHECKPOINT", "MAIN CHECKPOINT"], in: text) {
            results.append(.init(terminal: .domestic, checkpointName: "MAIN", minutes: m))
        }

        if let m = firstMinutes(afterAnyOf: ["DOMESTIC NORTH CHECKPOINT", "NORTH CHECKPOINT"], in: text) {
            results.append(.init(terminal: .domestic, checkpointName: "NORTH", minutes: m))
        }

        if let m = firstMinutes(afterAnyOf: ["LOWER NORTH CHECKPOINT"], in: text) {
            results.append(.init(terminal: .domestic, checkpointName: "LOWER NORTH", minutes: m))
        }

        // SOUTH often says "PRECHECK ONLY CHECKPOINT"
        if let m = firstMinutes(afterAnyOf: ["SOUTH PRECHECK ONLY CHECKPOINT", "SOUTH CHECKPOINT"], in: text) {
            results.append(.init(terminal: .domestic, checkpointName: "SOUTH", minutes: m))
        }

        // International can appear as "INT'L", "INT’L", or "INTERNATIONAL"
        if let m = firstMinutes(afterAnyOf: ["INT'L MAIN CHECKPOINT", "INT’L MAIN CHECKPOINT", "INTERNATIONAL MAIN CHECKPOINT", "INTL MAIN CHECKPOINT"], in: text) {
            results.append(.init(terminal: .international, checkpointName: "MAIN", minutes: m))
        }

        return results
    }

    // MARK: - Helpers

    /// Finds the first integer that appears shortly after any of the given markers.
    private static func firstMinutes(afterAnyOf markers: [String], in text: String) -> Int? {
        for marker in markers {
            if let minutes = firstMinutes(after: marker, in: text) {
                return minutes
            }
        }
        return nil
    }

    private static func firstMinutes(after marker: String, in text: String) -> Int? {
        guard let range = text.range(of: marker) else { return nil }

        // Look ahead a reasonable distance for the first number (0–120 typically)
        let start = range.upperBound
        let tail = String(text[start...])
        let lookahead = String(tail.prefix(300))

        // First 1–3 digit number
        let pattern = #"(\d{1,3})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let ns = lookahead as NSString
        let matches = regex.matches(in: lookahead, range: NSRange(location: 0, length: ns.length))
        for m in matches {
            let numStr = ns.substring(with: m.range(at: 1))
            if let n = Int(numStr) {
                return n
            }
        }
        return nil
    }

    private static func normalizedText(from html: String) -> String {
        // Strip tags -> uppercase -> normalize whitespace
        let noTags = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let upper = noTags.uppercased()
        return upper.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
