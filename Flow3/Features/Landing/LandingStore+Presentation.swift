import Foundation

struct AirportMetric: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let minutes: Int?
}

typealias AirportDisplayMetric = AirportMetric

struct AirportDisplayRow: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let metrics: [AirportMetric]
    let observedAt: Date?
}

extension LandingStore {

    func displayRowsForSelectedAirport() -> [AirportDisplayRow] {
        let rows = allWaitTimes()
            .filter { $0.airport == selectedAirport }

        switch selectedAirport {

        case .atl, .yvr, .yyc, .den, .dfw, .hou:
            return namedCheckpointRows(from: rows)

        case .jfk, .lhr, .yyz, .ams, .cdg, .dxb, .sin, .fra, .mad, .sfo, .lax, .ord, .bcn, .fco, .hnd, .icn, .syd:
            return terminalDisplayRows(from: rows)
        }
    }

    private func namedCheckpointRows(from rows: [WaitTimeEstimate]) -> [AirportDisplayRow] {
        let grouped = Dictionary(grouping: rows) { row in
            let checkpoint = row.checkpointName ?? "Security"
            let area = row.areaName ?? "Terminal"
            return "\(checkpoint)|\(area)"
        }

        return grouped
            .map { key, items in
                let parts = key.split(separator: "|").map(String.init)
                let title = parts.first ?? "Security"
                let subtitle = parts.count > 1 ? parts[1] : "Terminal"
                let observedAt = items.map(\.observedAt).max()

                let general = items.first(where: { $0.queueType == .general })?.minutes
                let precheck = items.first(where: { $0.queueType == .precheck })?.minutes

                let metrics: [AirportMetric]
                if items.contains(where: { $0.queueType == .precheck }) {
                    metrics = [
                        AirportMetric(label: "General", minutes: general),
                        AirportMetric(label: "PreCheck", minutes: precheck)
                    ]
                } else {
                    let bestMinutes = items.map(\.minutes).min()
                    metrics = [
                        AirportMetric(label: "Wait", minutes: bestMinutes)
                    ]
                }

                return AirportDisplayRow(
                    id: key,
                    title: title,
                    subtitle: subtitle,
                    metrics: metrics,
                    observedAt: observedAt
                )
            }
            .sorted { $0.title < $1.title }
    }

    private func terminalDisplayRows(from rows: [WaitTimeEstimate]) -> [AirportDisplayRow] {
        let grouped = Dictionary(grouping: rows) { $0.terminal ?? -1 }

        return grouped
            .compactMap { terminal, items -> AirportDisplayRow? in
                guard terminal >= 0 else { return nil }

                let title = "Terminal \(terminal)"
                let observedAt = items.map(\.observedAt).max()

                if selectedAirport == .yyz {
                    let best = items.min(by: { $0.minutes < $1.minutes })

                    return AirportDisplayRow(
                        id: "\(selectedAirport.rawValue)-T\(terminal)",
                        title: title,
                        subtitle: best?.checkpointName ?? "Security",
                        metrics: [
                            AirportMetric(label: "Wait", minutes: best?.minutes)
                        ],
                        observedAt: observedAt
                    )
                }

                let general = items.first(where: { $0.queueType == .general })?.minutes
                let precheck = items.first(where: { $0.queueType == .precheck })?.minutes

                if items.contains(where: { $0.queueType == .precheck }) {
                    return AirportDisplayRow(
                        id: "\(selectedAirport.rawValue)-T\(terminal)",
                        title: title,
                        subtitle: "Security",
                        metrics: [
                            AirportMetric(label: "General", minutes: general),
                            AirportMetric(label: "PreCheck", minutes: precheck)
                        ],
                        observedAt: observedAt
                    )
                } else {
                    let best = items.map(\.minutes).min()

                    return AirportDisplayRow(
                        id: "\(selectedAirport.rawValue)-T\(terminal)",
                        title: title,
                        subtitle: items.first?.checkpointName ?? "Security",
                        metrics: [
                            AirportMetric(label: "Wait", minutes: best)
                        ],
                        observedAt: observedAt
                    )
                }
            }
            .sorted { $0.title < $1.title }
    }
}
