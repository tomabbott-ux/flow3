import Foundation

extension LandingStore {

    func availableSecurityRoutes(
        for airport: FlowAirport? = nil
    ) -> [SecurityRouteOption] {
        let airport = airport ?? selectedAirport
        let rows = allWaitTimes()
            .filter { $0.airport == airport && !$0.isClosed }

        let grouped = Dictionary(grouping: rows) { routeGroupingKey(for: $0) }

        return grouped
            .compactMap { key, items in
                makeSecurityRouteOption(
                    airport: airport,
                    key: key,
                    items: items
                )
            }
            .sorted { lhs, rhs in
                if lhs.subtitle == rhs.subtitle {
                    if lhs.minutes == rhs.minutes {
                        return lhs.title < rhs.title
                    }
                    return lhs.minutes < rhs.minutes
                }
                return lhs.subtitle < rhs.subtitle
            }
    }

    func plannerSecuritySelection(
        for airport: FlowAirport? = nil,
        flightTerminal: String? = nil,
        preferredRouteID: String? = nil
    ) -> PlannerSecuritySelection {

        let airport = airport ?? selectedAirport
        let options = availableSecurityRoutes(for: airport)

        if let preferredRouteID,
           let manual = options.first(where: { $0.id == preferredRouteID }) {
            return PlannerSecuritySelection(
                mode: .manual,
                option: manual
            )
        }

        switch airport {

        case .atl:
            return atlPlannerSecuritySelection(
                options: options,
                flightTerminal: flightTerminal
            )

        default:
            if let best = options
                .filter({ !$0.isPreCheckOnly })
                .min(by: { $0.minutes < $1.minutes }) {
                return PlannerSecuritySelection(
                    mode: .automatic,
                    option: best
                )
            }

            let fallback = options.min(by: { $0.minutes < $1.minutes }) ??
                SecurityRouteOption(
                    id: "\(airport.rawValue)-AUTO",
                    title: "Fastest route",
                    subtitle: "",
                    detail: "Flow automatically selected the fastest checkpoint",
                    minutes: 0,
                    isPreCheckOnly: false
                )

            return PlannerSecuritySelection(
                mode: .automatic,
                option: fallback
            )
        }
    }

    func setTrackedFlightSecurityRoute(_ routeID: String?) {
        guard let current = trackedFlight else { return }

        let updated = TrackedFlight(
            flightNumber: current.flightNumber,
            route: current.route,
            airline: current.airline,
            terminal: current.terminal,
            departureTime: current.departureTime,
            leaveTime: current.leaveTime,
            gateTargetTime: current.gateTargetTime,
            travelMinutes: current.travelMinutes,
            securityMinutes: current.securityMinutes,
            airportBufferMinutes: current.airportBufferMinutes,
            bagBufferMinutes: current.bagBufferMinutes,
            leaveTimeTrend: current.leaveTimeTrend,
            securityRouteMode: routeID == nil ? .automatic : .manual,
            securityRouteID: routeID,
            securityRouteTitle: current.securityRouteTitle,
            securityRouteSubtitle: current.securityRouteSubtitle,
            securityRouteDetail: routeID == nil
                ? "Flow automatically selects the best checkpoint"
                : current.securityRouteDetail,
            securityRouteIsPreCheckOnly: current.securityRouteIsPreCheckOnly
        )

        trackedFlight = updated
        SavedFlightStore.shared.save(updated)

        Task {
            await refreshTrackedFlight()
        }
    }

    private func atlPlannerSecuritySelection(
        options: [SecurityRouteOption],
        flightTerminal: String?
    ) -> PlannerSecuritySelection {

        let normalizedTerminal = normalizePlannerTerminal(flightTerminal)

        if isATLInternationalTerminal(normalizedTerminal),
           let international = options
            .filter({
                !$0.isPreCheckOnly &&
                $0.subtitle.localizedCaseInsensitiveContains("International")
            })
            .min(by: { $0.minutes < $1.minutes }) {

            return PlannerSecuritySelection(
                mode: .automatic,
                option: international
            )
        }

        if let domestic = options
            .filter({
                !$0.isPreCheckOnly &&
                $0.subtitle.localizedCaseInsensitiveContains("Domestic")
            })
            .min(by: { $0.minutes < $1.minutes }) {

            return PlannerSecuritySelection(
                mode: .automatic,
                option: domestic
            )
        }

        if let fastestNonPreCheck = options
            .filter({ !$0.isPreCheckOnly })
            .min(by: { $0.minutes < $1.minutes }) {

            return PlannerSecuritySelection(
                mode: .automatic,
                option: fastestNonPreCheck
            )
        }

        let fallback = options.min(by: { $0.minutes < $1.minutes }) ??
            SecurityRouteOption(
                id: "ATL-AUTO",
                title: "Fastest route",
                subtitle: "",
                detail: "Flow automatically selected the fastest checkpoint",
                minutes: 0,
                isPreCheckOnly: false
            )

        return PlannerSecuritySelection(
            mode: .automatic,
            option: fallback
        )
    }

    private func routeGroupingKey(for row: WaitTimeEstimate) -> String {
        let checkpoint = row.checkpointName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let area = row.areaName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let terminal = row.terminal.map { "T\($0)" } ?? ""
        return "\(checkpoint)|\(area)|\(terminal)"
    }

    private func makeSecurityRouteOption(
        airport: FlowAirport,
        key: String,
        items: [WaitTimeEstimate]
    ) -> SecurityRouteOption? {

        let generalMinutes = items
            .filter { $0.queueType == .general }
            .map(\.minutes)
            .min()

        let preCheckMinutes = items
            .filter { $0.queueType == .precheck }
            .map(\.minutes)
            .min()

        guard let minutes = generalMinutes ?? preCheckMinutes else {
            return nil
        }

        let sample = items.first

        let checkpoint = sample?.checkpointName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let area = sample?.areaName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let title: String
        if !checkpoint.isEmpty {
            title = checkpoint
        } else if let terminal = sample?.terminal {
            title = "Terminal \(terminal)"
        } else {
            title = "Security"
        }

        let subtitle: String
        if !area.isEmpty {
            subtitle = area
        } else if let terminal = sample?.terminal {
            subtitle = "Terminal \(terminal)"
        } else {
            subtitle = ""
        }

        let isPreCheckOnly = generalMinutes == nil && preCheckMinutes != nil

        let detail: String
        if isPreCheckOnly {
            detail = subtitle.isEmpty
                ? "\(title) · PreCheck only"
                : "\(title) · \(subtitle) · PreCheck only"
        } else {
            detail = subtitle.isEmpty
                ? title
                : "\(title) · \(subtitle)"
        }

        return SecurityRouteOption(
            id: "\(airport.rawValue)|\(key)".uppercased(),
            title: title,
            subtitle: subtitle,
            detail: detail,
            minutes: minutes,
            isPreCheckOnly: isPreCheckOnly
        )
    }

    private func normalizePlannerTerminal(_ value: String?) -> String? {
        guard let value else { return nil }

        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        return cleaned.isEmpty ? nil : cleaned
    }

    private func isATLInternationalTerminal(_ terminal: String?) -> Bool {
        guard let terminal else { return false }

        if terminal == "I" { return true }
        if terminal == "INTL" { return true }
        if terminal == "INTERNATIONAL" { return true }
        if terminal.contains("INTL") { return true }
        if terminal.contains("INTERNATIONAL") { return true }

        return false
    }
}
