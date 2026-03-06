import Foundation

struct AirportDisplayMetric: Identifiable, Hashable {
    let id: String
    let label: String
    let minutes: Int?
}

struct AirportDisplayRow: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let metrics: [AirportDisplayMetric]
    let sortOrder: Int
}

extension LandingStore {

    func displayRowsForSelectedAirport() -> [AirportDisplayRow] {
        let airportWaits = allWaitTimes()
            .filter { $0.airport == selectedAirport }

        switch selectedAirport {
        case .atl:
            return makeATLRows(from: airportWaits)

        case .jfk:
            return makeJFKRows(from: airportWaits)

        case .lhr:
            return makeLHRRows(from: airportWaits)

        case .ams, .cdg, .dxb, .sin, .fra, .mad:
            return makeGenericTerminalRows(from: airportWaits)
        }
    }
}

// MARK: - ATL

private extension LandingStore {

    func makeATLRows(from waits: [WaitTimeEstimate]) -> [AirportDisplayRow] {
        waits
            .map { item in
                let checkpoint = item.checkpointName ?? "Checkpoint"
                let area = item.areaName ?? "Airport"

                let metricLabel = item.queueType == .precheck ? "PreCheck" : "Wait"
                let subtitle: String

                if item.queueType == .precheck {
                    subtitle = "\(area) • PreCheck Only"
                } else {
                    subtitle = "\(area) • Security"
                }

                let areaSort: Int
                switch area.lowercased() {
                case "domestic":
                    areaSort = 0
                case "international":
                    areaSort = 1
                default:
                    areaSort = 9
                }

                let checkpointSort = atlCheckpointSortOrder(checkpoint)

                return AirportDisplayRow(
                    id: "atl-\(area)-\(checkpoint)-\(metricLabel)",
                    title: checkpoint,
                    subtitle: subtitle,
                    metrics: [
                        AirportDisplayMetric(
                            id: "atl-metric-\(area)-\(checkpoint)-\(metricLabel)",
                            label: metricLabel,
                            minutes: item.minutes
                        )
                    ],
                    sortOrder: (areaSort * 100) + checkpointSort
                )
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func atlCheckpointSortOrder(_ checkpoint: String) -> Int {
        let upper = checkpoint.uppercased()

        if upper.contains("MAIN") { return 0 }
        if upper == "NORTH" { return 1 }
        if upper.contains("LOWER NORTH") { return 2 }
        if upper.contains("SOUTH") { return 3 }

        return 99
    }
}

// MARK: - JFK

private extension LandingStore {

    func makeJFKRows(from waits: [WaitTimeEstimate]) -> [AirportDisplayRow] {
        let terminals = Array(Set(waits.compactMap { $0.terminal })).sorted()

        return terminals.map { terminal in
            let terminalWaits = waits.filter { $0.terminal == terminal }

            let general = terminalWaits.first(where: { $0.queueType == .general })?.minutes
            let precheck = terminalWaits.first(where: { $0.queueType == .precheck })?.minutes

            return AirportDisplayRow(
                id: "jfk-\(terminal)",
                title: "Terminal \(terminal)",
                subtitle: "Security",
                metrics: [
                    AirportDisplayMetric(
                        id: "jfk-\(terminal)-general",
                        label: "General",
                        minutes: general
                    ),
                    AirportDisplayMetric(
                        id: "jfk-\(terminal)-precheck",
                        label: "PreCheck",
                        minutes: precheck
                    )
                ],
                sortOrder: terminal
            )
        }
    }
}

// MARK: - LHR

private extension LandingStore {

    func makeLHRRows(from waits: [WaitTimeEstimate]) -> [AirportDisplayRow] {
        let terminals = Array(Set(waits.compactMap { $0.terminal })).sorted()

        return terminals.map { terminal in
            let terminalWaits = waits.filter { $0.terminal == terminal }

            if terminal == 5 {
                let north = terminalWaits.first(where: { $0.queueType == .general })?.minutes
                let south = terminalWaits.first(where: { $0.queueType == .precheck })?.minutes

                return AirportDisplayRow(
                    id: "lhr-\(terminal)",
                    title: "Terminal \(terminal)",
                    subtitle: "Security",
                    metrics: [
                        AirportDisplayMetric(
                            id: "lhr-\(terminal)-north",
                            label: "North",
                            minutes: north
                        ),
                        AirportDisplayMetric(
                            id: "lhr-\(terminal)-south",
                            label: "South",
                            minutes: south
                        )
                    ],
                    sortOrder: terminal
                )
            } else {
                let minutes = terminalWaits.first(where: { $0.queueType == .general })?.minutes

                return AirportDisplayRow(
                    id: "lhr-\(terminal)",
                    title: "Terminal \(terminal)",
                    subtitle: "Security",
                    metrics: [
                        AirportDisplayMetric(
                            id: "lhr-\(terminal)-wait",
                            label: "Wait",
                            minutes: minutes
                        )
                    ],
                    sortOrder: terminal
                )
            }
        }
    }
}

// MARK: - Generic terminal airports

private extension LandingStore {

    func makeGenericTerminalRows(from waits: [WaitTimeEstimate]) -> [AirportDisplayRow] {
        let terminals = Array(Set(waits.compactMap { $0.terminal })).sorted()

        return terminals.map { terminal in
            let terminalWaits = waits.filter { $0.terminal == terminal }
            let minutes = terminalWaits.map { $0.minutes }.min()

            return AirportDisplayRow(
                id: "\(selectedAirport.rawValue)-\(terminal)",
                title: "Terminal \(terminal)",
                subtitle: "Security",
                metrics: [
                    AirportDisplayMetric(
                        id: "\(selectedAirport.rawValue)-\(terminal)-wait",
                        label: "Wait",
                        minutes: minutes
                    )
                ],
                sortOrder: terminal
            )
        }
    }
}
