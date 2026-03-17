import Foundation

enum ATLTerminal: String, Codable {
    case domestic = "DOMESTIC"
    case international = "INTL"
}

struct ATLSecurityCheckpointWait: Identifiable, Codable, Hashable {
    let id: String
    let terminal: ATLTerminal
    let checkpointName: String
    let minutes: Int?
    let isClosed: Bool

    init(
        terminal: ATLTerminal,
        checkpointName: String,
        minutes: Int?,
        isClosed: Bool
    ) {
        self.terminal = terminal
        self.checkpointName = checkpointName
        self.minutes = minutes
        self.isClosed = isClosed
        self.id = "\(terminal.rawValue)-\(checkpointName)".uppercased()
    }
}

enum ATLSecurityWaitTimesParser {

    private struct CheckpointSpec {
        let terminal: ATLTerminal
        let checkpointName: String
        let marker: String
    }

    static func parse(html: String) -> [ATLSecurityCheckpointWait] {
        let text = normalizedText(from: html)

        let specs: [CheckpointSpec] = [
            .init(terminal: .domestic, checkpointName: "MAIN", marker: "MAIN CHECKPOINT"),
            .init(terminal: .domestic, checkpointName: "NORTH", marker: "NORTH CHECKPOINT"),
            .init(terminal: .domestic, checkpointName: "LOWER NORTH", marker: "LOWER NORTH CHECKPOINT"),
            .init(terminal: .domestic, checkpointName: "SOUTH", marker: "SOUTH"),
            .init(terminal: .international, checkpointName: "MAIN", marker: "INT'L MAIN CHECKPOINT")
        ]

        var results: [ATLSecurityCheckpointWait] = []

        for index in specs.indices {
            let spec = specs[index]
            let nextMarkers = Array(specs[(index + 1)...].map(\.marker))
            if let item = checkpoint(for: spec, nextMarkers: nextMarkers, in: text) {
                results.append(item)
            }
        }

        return results
    }

    private static func checkpoint(
        for spec: CheckpointSpec,
        nextMarkers: [String],
        in text: String
    ) -> ATLSecurityCheckpointWait? {
        guard let block = block(for: spec.marker, nextMarkers: nextMarkers, in: text) else {
            return nil
        }

        if block.contains("CLOSED") {
            return ATLSecurityCheckpointWait(
                terminal: spec.terminal,
                checkpointName: spec.checkpointName,
                minutes: nil,
                isClosed: true
            )
        }

        guard let minutes = firstMinutes(in: block) else {
            return nil
        }

        return ATLSecurityCheckpointWait(
            terminal: spec.terminal,
            checkpointName: spec.checkpointName,
            minutes: minutes,
            isClosed: false
        )
    }

    private static func block(
        for marker: String,
        nextMarkers: [String],
        in text: String
    ) -> String? {
        guard let markerRange = text.range(of: marker) else { return nil }

        let contentStart = markerRange.lowerBound
        let remaining = String(text[contentStart...])

        var endIndex = remaining.endIndex

        for nextMarker in nextMarkers {
            if let nextRange = remaining.range(of: nextMarker),
               nextRange.lowerBound > remaining.startIndex,
               nextRange.lowerBound < endIndex {
                endIndex = nextRange.lowerBound
            }
        }

        return String(remaining[..<endIndex])
    }

    private static func firstMinutes(in text: String) -> Int? {
        let pattern = #"(\d{1,3})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))

        for match in matches {
            let numStr = ns.substring(with: match.range(at: 1))
            if let n = Int(numStr) {
                return n
            }
        }

        return nil
    }

    private static func normalizedText(from html: String) -> String {
        let noTags = html.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        let upper = noTags.uppercased()

        let normalizedQuotes = upper
            .replacingOccurrences(of: "INT’L", with: "INT'L")
            .replacingOccurrences(of: "INTL", with: "INT'L")

        return normalizedQuotes.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
    }
}
