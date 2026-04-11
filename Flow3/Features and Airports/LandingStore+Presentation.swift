import Foundation
import SwiftUI

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
    let isLive: Bool
}

extension LandingStore {

    func displayRowsForSelectedAirport() -> [AirportDisplayRow] {

        let rows = allWaitTimes()
            .filter { $0.airport == selectedAirport }

        guard !rows.isEmpty else { return [] }

        // MSP must be shown by checkpoint, not grouped by terminal,
        // otherwise T1 North / T1 South collapse into one Terminal 1 row.
        if selectedAirport == .msp {
            return namedCheckpointRows(from: rows)
        }

        if selectedAirport.prefersCheckpointPresentation {
            return namedCheckpointRows(from: rows)
        } else {
            return terminalDisplayRows(from: rows)
        }
    }

    private func namedCheckpointRows(from rows: [WaitTimeEstimate]) -> [AirportDisplayRow] {

        let grouped = Dictionary(grouping: rows) { row in
            let checkpoint = row.checkpointName ?? "Security"
            let area = row.areaName ?? ""
            return "\(checkpoint)|\(area)"
        }

        var displayRows = grouped
            .map { key, items in

                let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)

                let title = parts.first ?? "Security"
                let subtitle = parts.count > 1 ? parts[1] : ""
                let observedAt = items.map(\.observedAt).max()
                let isClosed = items.allSatisfy(\.isClosed)
                let isLive = items.contains { $0.sourceType == .live }

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
                    isClosed: isClosed,
                    isLive: isLive
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
                    isClosed: false,
                    isLive: rows.contains { $0.sourceType == .live }
                )
            )
        }

        return displayRows
            .sorted { lhs, rhs in
                if lhs.id == "SLC-PRECHECK-AVAILABLE" { return false }
                if rhs.id == "SLC-PRECHECK-AVAILABLE" { return true }

                if lhs.isClosed != rhs.isClosed {
                    return !lhs.isClosed
                }

                if selectedAirport == .atl {
                    let lhsArea = lhs.subtitle
                    let rhsArea = rhs.subtitle

                    if lhsArea != rhsArea {
                        if lhsArea == "Domestic" { return true }
                        if rhsArea == "Domestic" { return false }
                    }

                    let order = ["MAIN", "NORTH", "SOUTH", "LOWER NORTH"]
                    let lhsIndex = order.firstIndex(of: lhs.title) ?? 999
                    let rhsIndex = order.firstIndex(of: rhs.title) ?? 999

                    if lhsIndex != rhsIndex {
                        return lhsIndex < rhsIndex
                    }

                    return lhs.subtitle < rhs.subtitle
                }

                if selectedAirport == .msp {
                    let order = [
                        "T1 North",
                        "T1 South",
                        "T2 Checkpoint 1",
                        "T2 PreCheck"
                    ]

                    let lhsIndex = order.firstIndex(of: lhs.title) ?? 999
                    let rhsIndex = order.firstIndex(of: rhs.title) ?? 999

                    if lhsIndex != rhsIndex {
                        return lhsIndex < rhsIndex
                    }

                    if lhs.title == rhs.title {
                        return lhs.subtitle < rhs.subtitle
                    }

                    return lhs.title < rhs.title
                }

                if selectedAirport == .sea {
                    if lhs.title == rhs.title {
                        return lhs.subtitle < rhs.subtitle
                    }
                    return lhs.title < rhs.title
                }

                if lhs.title == rhs.title {
                    return lhs.subtitle < rhs.subtitle
                }

                return lhs.title < rhs.title
            }
            .uniqued(by: { $0.title + "|" + $0.subtitle })
    }

    private func terminalDisplayRows(from rows: [WaitTimeEstimate]) -> [AirportDisplayRow] {

        let cleanedRows = rows.compactMap { row -> WaitTimeEstimate? in

            if selectedAirport == .lax, row.terminal == 0 {
                return WaitTimeEstimate(
                    airport: row.airport,
                    terminal: 999,
                    queueType: row.queueType,
                    minutes: row.minutes,
                    observedAt: row.observedAt,
                    checkpointName: "Tom Bradley International Terminal",
                    areaName: row.areaName,
                    sourceType: row.sourceType,
                    isClosed: row.isClosed
                )
            }

            return row
        }

        let grouped: [String: [WaitTimeEstimate]]

        if selectedAirport == .lhr {
            grouped = Dictionary(grouping: cleanedRows) { row in
                let terminal = row.terminal ?? -1
                let checkpoint = row.checkpointName ?? "Security"
                return "\(terminal)|\(checkpoint)"
            }
        } else {
            grouped = Dictionary(grouping: cleanedRows) { row in
                "\(row.terminal ?? -1)"
            }
        }

        return grouped
            .compactMap { key, items -> AirportDisplayRow? in

                let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)

                guard let terminal = Int(parts.first ?? "-1"), terminal >= 0 else { return nil }
                if terminal == 0 { return nil }

                let checkpointName = parts.count > 1
                    ? parts[1]
                    : (items.first?.checkpointName ?? "Security")

                let isTBIT = terminal == 999 && selectedAirport == .lax
                let isLive = isTBIT || items.contains { $0.sourceType == .live }

                let title: String = isTBIT ? "Terminal B" : "Terminal \(terminal)"

                let subtitle: String = isTBIT
                    ? "Tom Bradley International Terminal"
                    : cleanedTerminalSubtitle(
                        title: title,
                        subtitle: checkpointName
                    )

                let observedAt = items.map(\.observedAt).max()
                let isClosed = items.allSatisfy(\.isClosed)

                let general = items.first(where: { $0.queueType == .general && !$0.isClosed })?.minutes
                let precheck = items.first(where: { $0.queueType == .precheck && !$0.isClosed })?.minutes

                let metrics: [AirportMetric]

                if isClosed {
                    metrics = [AirportMetric(label: "Closed", minutes: nil)]
                } else if isTBIT {
                    metrics = [
                        AirportMetric(label: "General", minutes: general ?? precheck),
                        AirportMetric(label: "PreCheck", minutes: precheck ?? general)
                    ]
                } else {
                    metrics = metricsForRow(
                        general: general,
                        precheck: precheck,
                        items: items,
                        isClosed: isClosed
                    )
                }

                return AirportDisplayRow(
                    id: "\(selectedAirport.rawValue)-T\(terminal)-\(checkpointName)",
                    title: title,
                    subtitle: subtitle,
                    metrics: metrics,
                    observedAt: observedAt,
                    isClosed: isClosed,
                    isLive: isLive
                )
            }
            .sorted { lhs, rhs in

                if lhs.title == "Terminal B" { return true }
                if rhs.title == "Terminal B" { return false }

                func extractNumber(_ title: String) -> Int {
                    let cleaned = title.replacingOccurrences(of: "Terminal ", with: "")
                    return Int(cleaned) ?? 999
                }

                let lhsTerminal = extractNumber(lhs.title)
                let rhsTerminal = extractNumber(rhs.title)

                if lhsTerminal != rhsTerminal {
                    return lhsTerminal < rhsTerminal
                }

                if selectedAirport == .lhr {
                    let order = ["Security", "North", "South"]
                    let lhsIndex = order.firstIndex(of: lhs.subtitle) ?? 999
                    let rhsIndex = order.firstIndex(of: rhs.subtitle) ?? 999

                    if lhsIndex != rhsIndex {
                        return lhsIndex < rhsIndex
                    }
                }

                return lhs.subtitle < rhs.subtitle
            }
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
                AirportMetric(label: "General", minutes: general)
            ]
        }

        let bestMinutes = items
            .filter { !$0.isClosed }
            .map(\.minutes)
            .min()

        return [
            AirportMetric(label: "General", minutes: bestMinutes)
        ]
    }
}

extension Array {
    func uniqued<T: Hashable>(by key: (Element) -> T) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert(key($0)).inserted }
    }
}
