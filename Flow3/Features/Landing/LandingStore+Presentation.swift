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
    let isClosed: Bool
}

extension LandingStore {

    func displayRowsForSelectedAirport() -> [AirportDisplayRow] {

        let rows = allWaitTimes()
            .filter { $0.airport == selectedAirport }

        switch selectedAirport {

        case .atl, .ist, .slc, .iah, .ham, .dus, .edi, .str, .bru,
             .arn, .got, .osl, .doh, .zrh, .hel,
             .yvr, .yyc, .den, .dfw, .hou, .mco, .phx,
             .phl, .san, .las, .bos, .sea, .mia, .sfo,
             .bna, .tpa, .dtw, .clt, .ewr, .bwi, .dca, .pdx,
             .fra, .lhr:
            return namedCheckpointRows(from: rows)

        case .jfk, .lga, .cph, .yyz, .ams, .cdg, .dxb, .sin, .mad,
             .lax, .ord, .fco, .bcn, .hnd, .icn, .syd, .msp:
            return terminalDisplayRows(from: rows)
        }
    }

    private func namedCheckpointRows(from rows: [WaitTimeEstimate]) -> [AirportDisplayRow] {

        let grouped = Dictionary(grouping: rows) { row in
            let checkpoint = row.checkpointName ?? "Security"
            let area = row.areaName ?? terminalSubtitle(for: row)
            return "\(checkpoint)|\(area)"
        }

        var displayRows = grouped
            .map { key, items in

                let parts = key.split(separator: "|").map(String.init)

                let title = parts.first ?? "Security"
                let subtitle = parts.count > 1 ? parts[1] : "Terminal"

                let observedAt = items.map(\.observedAt).max()
                let isClosed = items.allSatisfy(\.isClosed)

                let general = items.first(where: { $0.queueType == .general && !$0.isClosed })?.minutes
                let precheck = items.first(where: { $0.queueType == .precheck && !$0.isClosed })?.minutes

                let metrics = metricsForRow(
                    general: general,
                    precheck: precheck,
                    items: items,
                    isClosed: isClosed
                )

                return AirportDisplayRow(
                    id: key,
                    title: title,
                    subtitle: subtitle,
                    metrics: metrics,
                    observedAt: observedAt,
                    isClosed: isClosed
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
                    observedAt: observedAt,
                    isClosed: false
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

                guard terminal >= 0 else { return nil }

                let title: String

                if selectedAirport == .lga {

                    switch terminal {
                    case 1:
                        title = "Terminal A"
                    case 2:
                        title = "Terminal B"
                    case 3:
                        title = "Terminal C"
                    case 4:
                        title = "Terminal D"
                    default:
                        title = "Terminal \(terminal)"
                    }

                } else {

                    title = "Terminal \(terminal)"

                }

                let observedAt = items.map(\.observedAt).max()
                let isClosed = items.allSatisfy(\.isClosed)

                if selectedAirport == .yyz {
                    let best = items
                        .filter { !$0.isClosed }
                        .min(by: { $0.minutes < $1.minutes })

                    return AirportDisplayRow(
                        id: "\(selectedAirport.rawValue)-T\(terminal)",
                        title: title,
                        subtitle: isClosed ? "Closed" : cleanedTerminalSubtitle(title: title, subtitle: best?.checkpointName ?? "Security"),
                        metrics: isClosed
                            ? [AirportMetric(label: "Closed", minutes: nil)]
                            : [AirportMetric(label: "Wait", minutes: best?.minutes)],
                        observedAt: observedAt,
                        isClosed: isClosed
                    )
                }

                let general = items.first(where: { $0.queueType == .general && !$0.isClosed })?.minutes
                let precheck = items.first(where: { $0.queueType == .precheck && !$0.isClosed })?.minutes

                let metrics = metricsForRow(
                    general: general,
                    precheck: precheck,
                    items: items,
                    isClosed: isClosed
                )

                let subtitle = isClosed
                    ? "Closed"
                    : cleanedTerminalSubtitle(title: title, subtitle: items.first?.checkpointName ?? "Security")

                return AirportDisplayRow(
                    id: "\(selectedAirport.rawValue)-T\(terminal)",
                    title: title,
                    subtitle: subtitle,
                    metrics: metrics,
                    observedAt: observedAt,
                    isClosed: isClosed
                )
            }
            .sorted { $0.title < $1.title }
    }

    private func terminalSubtitle(for row: WaitTimeEstimate) -> String {
        if let terminal = row.terminal {
            return "Terminal \(terminal)"
        }
        return "Terminal"
    }

    private func cleanedTerminalSubtitle(title: String, subtitle: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmedSubtitle.isEmpty {
            return "Security"
        }

        if trimmedTitle == trimmedSubtitle {
            return "Security"
        }

        return subtitle
    }

    private func metricsForRow(
        general: Int?,
        precheck: Int?,
        items: [WaitTimeEstimate],
        isClosed: Bool
    ) -> [AirportMetric] {

        if isClosed {
            return [
                AirportMetric(label: "Closed", minutes: nil)
            ]
        }

        if general != nil && precheck != nil {
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

        let bestMinutes = items
            .filter { !$0.isClosed }
            .map(\.minutes)
            .min()

        return [
            AirportMetric(label: "Wait", minutes: bestMinutes)
        ]
    }
}
