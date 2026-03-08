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

        case .atl, .ist, .slc, .yvr, .yyc, .den, .dfw, .hou, .mco, .phx, .phl,
             .san, .las, .bos, .sea, .mia:
            return namedCheckpointRows(from: rows)

        case .jfk, .lhr, .yyz, .ams, .cdg, .dxb, .sin, .fra, .mad,
             .sfo, .lax, .ord,
             .bcn, .fco, .hnd, .icn, .syd:
            return terminalDisplayRows(from: rows)
        }
    }

    private func namedCheckpointRows(from rows: [WaitTimeEstimate]) -> [AirportDisplayRow] {
        let grouped = Dictionary(grouping: rows) { row in
            let checkpoint = row.checkpointName ?? "Security"
            let area = row.areaName ?? "Terminal"
            return "\(checkpoint)|\(area)"
        }

        var displayRows = grouped
            .map { key, items in
                let parts = key.split(separator: "|").map(String.init)
                let title = parts.first ?? "Security"
                let subtitle = parts.count > 1 ? parts[1] : "Terminal"
                let observedAt = items.map(\.observedAt).max()

                let general = items.first(where: { $0.queueType == .general })?.minutes
                let precheck = items.first(where: { $0.queueType == .precheck })?.minutes

                let metrics = metricsForRow(general: general, precheck: precheck, items: items)

                return AirportDisplayRow(
                    id: key,
                    title: title,
                    subtitle: subtitle,
                    metrics: metrics,
                    observedAt: observedAt
                )
            }

        if selectedAirport == .slc,
           let observedAt = rows.map(\.observedAt).max() {
            displayRows.append(
                AirportDisplayRow(
                    id: "SLC-PRECHECK-AVAILABLE",
                    title: "PreCheck",
                    subtitle: "Available",
                    metrics: [
                        AirportMetric(label: "PreCheck", minutes: nil)
                    ],
                    observedAt: observedAt
                )
            )
        }

        return displayRows.sorted { lhs, rhs in
            if lhs.id == "SLC-PRECHECK-AVAILABLE" { return false }
            if rhs.id == "SLC-PRECHECK-AVAILABLE" { return true }

            if lhs.subtitle == rhs.subtitle {
                return lhs.title < rhs.title
            }
            return lhs.subtitle < rhs.subtitle
        }
    }

    private func terminalDisplayRows(from rows: [WaitTimeEstimate]) -> [AirportDisplayRow] {
        let grouped = Dictionary(grouping: rows) { $0.terminal ?? -1 }

        return grouped
            .compactMap { terminal, items -> AirportDisplayRow? in
                guard terminal >= 0 else {
                    return nil
                }

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
                let metrics = metricsForRow(general: general, precheck: precheck, items: items)

                return AirportDisplayRow(
                    id: "\(selectedAirport.rawValue)-T\(terminal)",
                    title: title,
                    subtitle: items.first?.checkpointName ?? "Security",
                    metrics: metrics,
                    observedAt: observedAt
                )
            }
            .sorted { $0.title < $1.title }
    }

    private func metricsForRow(
        general: Int?,
        precheck: Int?,
        items: [WaitTimeEstimate]
    ) -> [AirportMetric] {

        if general != nil, precheck != nil {
            return [
                AirportMetric(label: "General", minutes: general),
                AirportMetric(label: "PreCheck", minutes: precheck)
            ]
        }

        if precheck != nil {
            return [
                AirportMetric(label: "PreCheck", minutes: precheck)
            ]
        }

        if general != nil {
            return [
                AirportMetric(label: "Wait", minutes: general)
            ]
        }

        let bestMinutes = items.map(\.minutes).min()

        return [
            AirportMetric(label: "Wait", minutes: bestMinutes)
        ]
    }
}
